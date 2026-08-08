#!/bin/bash
# author: indiff
set -xe

find /opt/vcpkg/installed -name "*.so*"
find /opt/vcpkg/installed -name "*.a*"

PROTOC_BASENAME=$(basename $(find /opt/vcpkg/installed/x64-linux-dynamic/tools/protobuf -maxdepth 1 -name "protoc-*" | head -1))
#PROTOC_LIB_BASENAME=$(basename $(find /opt/vcpkg/installed/x64-linux-dynamic/lib -maxdepth 1 -name "libprotoc*.so*" | head -1))
LIBPROTOBUF_BASENAME=libprotobuf.so
chmod +x /opt/vcpkg/installed/x64-linux-dynamic/tools/protobuf/${PROTOC_BASENAME}



if [[ -z "$FBMYSQL_BRANCH" ]]; then
  git clone --filter=blob:none --depth 1 https://github.com/facebook/mysql-5.6.git server
else
  git clone --filter=blob:none --depth 1 https://github.com/facebook/mysql-5.6.git -b $FBMYSQL_BRANCH server
fi

cd server
git submodule update --init --recursive


# patch zlib.h
sed -i '1i#ifndef Z_ARG\n#define Z_ARG(args) args\n#endif\n' extra/zlib/zlib-1.2.13/zlib.h || true

# Fix: myrg_static.cc has #ifndef stdin guard that skips myrg_def.h when stdin is
# defined (happens with GCC 17 + -include string). Remove the guard so myrg_def.h
# is always included, and add missing mysql/psi/mysql_mutex.h for PSI_mutex_key etc.
sed -i '/#ifndef stdin/d' storage/myisammrg/myrg_static.cc
sed -i '/#include "storage\/myisammrg\/myrg_def.h"/{n;/#endif/d}' storage/myisammrg/myrg_static.cc
sed -i '/#include "mysql\/psi\/mysql_memory.h"/a #include "mysql/psi/mysql_mutex.h"' storage/myisammrg/myrg_static.cc

DEPS_SRC="$VCPKG_ROOT/installed/x64-linux"
DEPS_DST="$FBMYSQL_INSTALL_PREFIX"
mkdir -p "$DEPS_DST"/{include,lib,lib64,tools}

# sync icu
rsync -a "/usr/local/icu/include/" "$DEPS_DST/include/" || true
rsync -a "/usr/local/icu/lib/"    "$DEPS_DST/lib/"    || true

# 2) 复制头文件与动态库（.so 与 .so.*）及 pkgconfig
rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a --copy-links "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true
# rsync -a --copy-links "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true
rsync -a --copy-links "$DEPS_SRC/tools/protobuf/"    "$DEPS_DST/tools/"    || true

DEPS_SRC="$VCPKG_ROOT/installed/x64-linux-dynamic"

rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a --copy-links "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true
# rsync -a --copy-links "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true
rsync -a --copy-links "$DEPS_SRC/tools/protobuf/"    "$DEPS_DST/tools/"    || true
        
rsync -a "/opt/gcc-indiff/include/" "$DEPS_DST/include/"
rsync -a --copy-links "/opt/gcc-indiff/lib64/"    "$DEPS_DST/lib64/"    || true

# 如果宿主镜像/系统有 /lib64/libjemalloc.so.1 同步到目标目录
if [ -f /lib64/libjemalloc.so.1 ]; then
echo "Found /lib64/libjemalloc.so.1 on build host, copying to $DEPS_DST/lib64"
mkdir -p "$DEPS_DST/lib64"
cp -a /lib64/libjemalloc.so* "$DEPS_DST/lib64/" || true
chmod 644 "$DEPS_DST/lib64"/libjemalloc.so* 2>/dev/null || true
fi

for d in lib lib64; do
[[ -d "$DEPS_DST/$d/pkgconfig" ]] || mkdir -p "$DEPS_DST/$d/pkgconfig"
rsync -a "$DEPS_SRC/$d/pkgconfig/" "$DEPS_DST/$d/pkgconfig/" 2>/dev/null || true
done

export CC="/opt/gcc-indiff/bin/gcc"
export CXX="/opt/gcc-indiff/bin/g++"
export CPPFLAGS="-I$DEPS_DST/include"
export LDFLAGS="-L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} -fuse-ld=mold"
export ACLOCAL_PATH=/usr/share/aclocal:${ACLOCAL_PATH:-}


# 克隆官方仓库（或镜像）
git clone https://github.com/autotools-mirror/autoconf.git
cd autoconf
./bootstrap     # 如果存在
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..

function wget_gnu(){
     local suffix=$1
     wget https://ftp.gnu.org/gnu/$suffix || wget https://mirrors.aliyun.com/gnu/$suffix || wget http://mirrors.tencent.com/gnu/$suffix
}
          
pkg-config --version || true
wget https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz
tar xzf pkg-config-0.29.2.tar.gz
cd pkg-config-0.29.2
./configure --prefix=/usr --with-internal-glib
make CFLAGS="-Ubool -std=gnu11 -O2" -j$(nproc)
make install
pkg-config --version
cd ..

# insatll automake
# git clone --depth=1 https://github.com/autotools-mirror/automake.git
# wget https://ftp.gnu.org/gnu/automake/automake-1.18.1.tar.gz
wget_gnu automake/automake-1.18.1.tar.gz
tar -xzf automake-1.18.1.tar.gz
cd automake-1.18.1
./bootstrap     # 如果存在
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..


# insatll libtool
# git clone --depth=1 https://https.git.savannah.gnu.org/git/libtool.git
# wget http://mirrors.tencent.com/gnu/libtool/libtool-2.5.4.tar.gz
wget_gnu libtool/libtool-2.6.2.tar.gz
tar -xzf libtool-2.6.2.tar.gz
cd libtool-2.6.2
./bootstrap  --force     # 如果存在
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..

# wget https://ftp.gnu.org/gnu/m4/m4-1.4.20.tar.gz
wget_gnu m4/m4-latest.tar.gz
tar -xzf m4-latest.tar.gz
cd m4-*
env CC=/opt/gcc-indiff/bin/gcc CFLAGS="-I/opt/gcc-indiff/include " \
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..
m4 --version

# export CFLAGS="-Wall "
# --with-staticsasl

git clone --filter=blob:none --depth 1 https://github.com/cyrusimap/cyrus-sasl.git
cd cyrus-sasl
autoreconf -fi
./configure --with-openssl="$DEPS_DST" --prefix="$DEPS_DST"
make -j$(nproc)
make install
cd ..
unset CPPFLAGS
unset LDFLAGS


# 显示一下目录接口查看是否存在相关的 lib 和 include
# tree "$DEPS_DST"/{include,lib,lib64} | tee /workspace/deps_dst_tree.txt
tree "$DEPS_DST"/{include,lib,lib64} > /workspace/deps_dst_tree.txt

# set boost
# mkdir -p /workspace/server/build /workspace/boost
# git clone --filter=blob:none --depth 1 https://github.com/boostorg/boost.git /workspace/boost
# cd /workspace/boost
# git submodule update --init --recursive

# wget https://archives.boost.io/release/1.89.0/source/boost_1_89_0.tar.bz2
# mkdir -p /tmp/boost
# tar -xjf boost_1_89_0.tar.bz2 -C /tmp/boost --strip-components=1
# wget  https://boostorg.jfrog.io/artifactory/main/release/1.77.0/source/boost_1_77_0.tar.bz2

boost_version_str="boost_1_87_0"
# wget https://archives.boost.io/release/1.87.0/source/${boost_version_str}.tar.bz2
mkdir -p /tmp/boost
#tar -xjf ${boost_version_str}.tar.bz2 -C /tmp/boost --strip-components=1


# ====== 替换 boost.cmake ======
cat > /workspace/server/cmake/boost1.cmake << BOOST_CMAKE_EOF
SET(BOOST_PACKAGE_NAME "${boost_version_str}")

# Always use the bundled version.
SET(BOOST_SOURCE_DIR "/tmp/boost")

# Contains all header files we need.
# (All the directories that contain at least one needed file).
SET(BOOST_INCLUDE_DIR \${BOOST_SOURCE_DIR})

ADD_LIBRARY(boost INTERFACE)
ADD_LIBRARY(extra::boost ALIAS boost)

TARGET_INCLUDE_DIRECTORIES(boost SYSTEM BEFORE INTERFACE \${BOOST_INCLUDE_DIR})

IF(NOT WIN32)
  # See boost/container_hash/hash.hpp
  # We pretend that the compiler is pre-c++98, in order to hide the
  # usage of std::unary_function<..> (which was removed in C++17)
  # For windows: see boost/config/stdlib/dinkumware.hpp
  TARGET_COMPILE_DEFINITIONS(boost INTERFACE BOOST_NO_CXX98_FUNCTION_BASE)
ENDIF()

MESSAGE(STATUS "BOOST_INCLUDE_DIR \${BOOST_INCLUDE_DIR}")
BOOST_CMAKE_EOF

sed -i 's|https://boostorg.jfrog.io/artifactory/main/release|https://archives.boost.io/release|g' /workspace/server/cmake/boost.cmake

cat /workspace/server/cmake/boost.cmake

mkdir /workspace/server/build
cd /workspace/server/build

# 供 CMake/ld 查找 vcpkg 拷贝到 /opt 的头文件与库
export CMAKE_PREFIX_PATH="$DEPS_DST${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export CMAKE_LIBRARY_PATH="$DEPS_DST/lib:$DEPS_DST/lib64${CMAKE_LIBRARY_PATH:+:$CMAKE_LIBRARY_PATH}"
export CMAKE_INCLUDE_PATH="$DEPS_DST/include${CMAKE_INCLUDE_PATH:+:$CMAKE_INCLUDE_PATH}"
export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/share/pkgconfig:$DEPS_DST/lib/pkgconfig:$DEPS_DST/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# 链接期搜索路径(关键修复 -ljemalloc not found)
export LIBRARY_PATH="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LIBRARY_PATH:+:$LIBRARY_PATH}"
export LD_LIBRARY_PATH="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# 避免外部 protobuf 干扰
# cmake ../server -DCONC_WITH_{UNITTEST,SSL}=OFF 
# -DWITH_UNIT_TESTS=OFF 
# -DCMAKE_BUILD_TYPE=Debug 
# -DWITHOUT_DYNAMIC_PLUGIN=ON -DWITH_SAFEMALLOC=OFF -DWITH_SSL=bundled -DMYSQL_MAINTAINER_MODE=OFF -G Ninja
# -DCMAKE_CXX_STANDARD=20
# -std=gnu++20
# 临时修复方案
# cp /opt/gcc-indiff/include/c++/16/bits/intcmp.h /opt/gcc-indiff/include/c++/16/bits/intcmp.h.bak
# sed -i 's/\bin_range\b/__in_range/g' /opt/gcc-indiff/include/c++/16/bits/intcmp.h

# WITH_PROTOBUF调整 bundle
# -DWITH_PROTOBUF=system  \
# -DPROTOBUF_LIBRARY="$DEPS_DST/lib/$LIBPROTOBUF_BASENAME" \
# -DPROTOBUF_PROTOC_EXECUTABLE="$VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME"  \
#  -include cstdint -include cstddef
# -DPROTOBUF_PROTOC_LIBRARY=${CONDA_PREFIX}/src/protobuf/libprotoc.a \
#     -DPROTOBUF_LITE_LIBRARIES="/opt/vcpkg/installed/x64-linux-dynamic/lib/libprotobuf-lite.so" \
#     -DWITH_LTO=ON \

rsync -a /opt/vcpkg/installed/x64-linux/include/ /opt/fbmysql/include/
rsync -a /opt/vcpkg/installed/x64-linux-dynamic/include/ /opt/fbmysql/include/

# cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo -DWITH_SSL=system \
#-DWITH_ZLIB=bundled -DMYSQL_MAINTAINER_MODE=0 -DENABLED_LOCAL_INFILE=1 \
#-DENABLE_DTRACE=0 -DCMAKE_CXX_FLAGS="-march=native"
# make -j8

# Manually-specified variables were not used by the project:
#  ENABLE_DTRACE
#     -DENABLE_PSI
#     HAVE_PSI_INTERFACE
#     WITH_BENCHMARK_TOOLS
#     WITH_DOCS
#     WITH_EXT_BACKTRACE
#     WITH_GFLAGS
#     WITH_MAN_PAGES
#     WITH_PERFORMANCE_SCHEMA
#     WITH_RAPID
#     WITH_ROCKSDB
#     WITH_SAFEMALLOC
#     WITH_TESTS


unset PROTOC
cmake .. -G Ninja \
    -DCMAKE_INSTALL_PREFIX=$DEPS_DST \
    -DCMAKE_C_FLAGS=" -D__NO_STRING_INLINES -I$DEPS_DST/include -O2 -pipe -fPIC -DPIC " \
    -DCMAKE_CXX_FLAGS="-Uin_range -std=c++20 -include cstdint -include cstddef -D__NO_STRING_INLINES -I$DEPS_DST/include -O2 -pipe -fPIC -DPIC " \
    -DCMAKE_CXX_EXTENSIONS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="-L/opt/vcpkg/installed/x64-linux/lib -L/usr/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -lpthread $(pkg-config --static --libs protobuf) -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DCMAKE_MODULE_LINKER_FLAGS="-L/usr/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DCMAKE_TOOLCHAIN_FILE="/opt/vcpkg/scripts/buildsystems/vcpkg.cmake" \
    -DVCPKG_TARGET_TRIPLET="x64-linux" \
    -DHAVE_PSI_INTERFACE=ON \
    -DDEFAULT_CHARSET="utf8mb4" \
    -DDEFAULT_COLLATION="utf8mb4_bin" \
    -DENABLED_LOCAL_INFILE=1 \
    -DWITH_BOOST="/tmp/boost" -DDOWNLOAD_BOOST=1 \
    -DWITHOUT_GROUP_REPLICATION=1 -DWITH_GROUP_REPLICATION=OFF \
    -DWITH_TESTS=0 \
    -DWITH_BENCHMARK_TOOLS=0 \
    -DWITH_GFLAGS=0 \
    -DWITH_NDB=OFF \
    -DWITH_MYSQLX=0 \
    -DWITH_NDB_JAVA=0 \
    -DWITH_RAPID=0 \
    -DWITH_ROUTER=0 \
    -DWITH_UNIT_TESTS=OFF \
    -DWITH_READLINE=bundled \
    -DWITH_ROCKSDB=ON \
    -DWITH_INNODB_MEMCACHED=ON \
    -DWITH_CURL=system \
    -DWITH_LIBEVENT=system \
    -DWITH_ZLIB=system -DWITH_LZ4=system -DWITH_ZSTD=system -DWITH_SNAPPY=system \
    -DWITH_PROTOBUF=system \
    -DPROTOBUF_INCLUDE_DIR="/opt/fbmysql/include" \
    -DPROTOBUF_LIBRARY="/opt/vcpkg/installed/x64-linux-dynamic/lib/libprotobuf.so" \
    -DPROTOBUF_PROTOC_EXECUTABLE="/opt/vcpkg/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME"  \
    -DPROTOBUF_PROTOC_LIBRARY="/opt/vcpkg/installed/x64-linux-dynamic/lib/libprotoc.so" \
    -DPROTOBUF_LITE_LIBRARY="/opt/vcpkg/installed/x64-linux-dynamic/lib/libprotobuf-lite.so" \
    -DWITH_ICU=system -DWITH_EDITLINE=bundled \
    -DWITH_SSL=system -DOPENSSL_ROOT_DIR="$DEPS_DST" \
    -DWITH_FIDO=system \
    -DWITH_MECAB=OFF \
    -DWITH_EXT_BACKTRACE=OFF \
    -DWITH_NUMA=OFF \
    -DWITH_PERFORMANCE_SCHEMA=ON -DWITH_MYISAM=ON -DENABLE_PSI=1 -DHAVE_PSI_INTERFACE=1 \
    -DWITH_ARCHIVE_STORAGE_ENGINE=OFF \
    -DWITH_BLACKHOLE_STORAGE_ENGINE=OFF \
    -DWITH_EXAMPLE_STORAGE_ENGINE=ON \
    -DWITH_FEDERATED_STORAGE_ENGINE=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DMYSQL_MAINTAINER_MODE=OFF \
    -DWITH_SAFEMALLOC=OFF \
    -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib64:$ORIGIN/../lib' \
    -DCMAKE_BUILD_RPATH='$ORIGIN/../lib64:$ORIGIN/../lib' \
    -DBUILD_CONFIG=mysql_release \
    -DWITH_DOCS=OFF -DWITH_MAN_PAGES=OFF -DMYSQL_SERVER_SUFFIX="-indiff"

# cmake .. -LH | tee /workspace/cmake-cache-vars-centos7.txt

# Ninja 默认详细，便于定位真实失败点
# 只会编译并安装最终产物(不会编译 tests)  [3343/4756]
cmake --build . -j"$(nproc)" --target install
cmake --install .

cd $DEPS_DST
rm -rf $DEPS_DST/sql-bench
rm -rf $DEPS_DST/man
rm -rf $DEPS_DST/mariadb-test
rm -rf $DEPS_DST/mysql-test
rm -rf $DEPS_DST/bin/mysqld-debug
rm -rf $DEPS_DST/sbin/mysqld-debug
rm -f $DEPS_DST/bin/mysqltest_safe_process
rm -f $DEPS_DST/bin/ps_mysqld_helper
rm -f $DEPS_DST/bin/ps-admin
rm -f $DEPS_DST/bin/mysqltest
rm -f $DEPS_DST/bin/mysqlxtest
rm -f $DEPS_DST/bin/mytap
rm -f $DEPS_DST/lib/*.a
rm -f $DEPS_DST/lib64/*.a
zip -r -q -9 /workspace/fbmysql-centos7-x86_64-$FBMYSQL_BRANCH-$(date +'%Y%m%d_%H%M').xz .

# free memory
free -h
# sync
# echo 3 > /proc/sys/vm/drop_caches
# free -h && df -h