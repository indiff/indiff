#!/bin/bash
# author: indiff
set -xe


find /opt/vcpkg/installed -name "*.so*"
find /opt/vcpkg/installed -name "*.a*"

PROTOC_BASENAME=$(basename $(find /opt/vcpkg/installed/x64-linux-dynamic/tools/protobuf -maxdepth 1 -name "protoc-*" | head -1))
#PROTOC_LIB_BASENAME=$(basename $(find /opt/vcpkg/installed/x64-linux-dynamic/lib -maxdepth 1 -name "libprotoc*.so*" | head -1))
LIBPROTOBUF_BASENAME=libprotobuf.so
chmod +x /opt/vcpkg/installed/x64-linux-dynamic/tools/protobuf/${PROTOC_BASENAME}

TRIPLET=x64-linux
DEPS_SRC="$VCPKG_ROOT/installed/$TRIPLET"
DEPS_DST="$PERCONA_INSTALL_PREFIX"
## use lld-indiff
# curl -#Lo lld-indiff.zip "https://github.com/indiff/gcc-build/releases/download/20251126_1903_16.0.0/lld-indiff-centos7-x86_64-20251126_1903.xz"
# unzip lld-indiff.zip -d /opt/gcc-indiff
export LD_LIBRARY_PATH="/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib:$LD_LIBRARY_PATH"
rm -f /usr/bin/ld.mold
ln -sf /opt/gcc-indiff/bin/ld.mold /usr/bin/ld.mold
/opt/gcc-indiff/bin/gcc -fuse-ld=mold -Wl,--version -xc - <<< 'int main(){return 0;}'
# export LDFLAGS="-fuse-ld=lld"
export LDFLAGS="-fuse-ld=mold"

mkdir -p "$DEPS_DST"/{include,lib,lib64}


DEPS_SRC="$VCPKG_ROOT/installed/x64-linux"
# sync icu
rsync -a "/usr/local/icu/include/" "$DEPS_DST/include/" || true
rsync -a "/usr/local/icu/lib/"    "$DEPS_DST/lib/"    || true

# sync jemalloc 
rsync -a "/opt/fbjemalloc/include/" "$DEPS_DST/include/"
rsync -a "/opt/fbjemalloc/lib/"    "$DEPS_DST/lib64/"    || true

rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a --copy-links "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true
# rsync -a --copy-links "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true

# PROTOC_BASENAME=$(basename $VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/protoc-*)
# PROTOC_LIB_BASENAME=$(basename $VCPKG_ROOT/installed/x64-linux-dynamic/lib/libprotoc.so.*)
# chmod +x $VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME
rsync -a "/opt/gcc-indiff/include/" "$DEPS_DST/include/"
rsync -a --copy-links "/opt/gcc-indiff/lib64/" "$DEPS_DST/lib64/" || true
rsync -a --copy-links "/opt/gcc-indiff/lib64/" "$DEPS_DST/lib/" || true

DEPS_SRC="$VCPKG_ROOT/installed/x64-linux-dynamic"

# 2) 复制头文件与动态库（.so 与 .so.*）及 pkgconfig
rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true

# rsync -a --copy-links "$DEPS_SRC/tools/protobuf/"    "$DEPS_DST/tools/"    || true
# PROTOC_BASENAME=$(basename $DEPS_DST/tools/protoc-*)
# PROTOC_LIB_BASENAME=$(basename $DEPS_DST/lib/libprotoc.so.*)
# chmod +x $DEPS_DST/tools/$PROTOC_BASENAME

# rsync -a "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true
ls "$DEPS_SRC/lib/*.a" || true
ls "$DEPS_DST/lib/*.a" || true

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

# 供 CMake/ld 查找 vcpkg 拷贝到 /opt 的头文件与库
export CMAKE_PREFIX_PATH="$DEPS_DST${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export CMAKE_LIBRARY_PATH="$DEPS_DST/lib:$DEPS_DST/lib64${CMAKE_LIBRARY_PATH:+:$CMAKE_LIBRARY_PATH}"
export CMAKE_INCLUDE_PATH="$DEPS_DST/include${CMAKE_INCLUDE_PATH:+:$CMAKE_INCLUDE_PATH}"
export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/share/pkgconfig:$DEPS_DST/lib/pkgconfig:$DEPS_DST/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# 链接期搜索路径(关键修复 -ljemalloc not found)
export LIBRARY_PATH="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LIBRARY_PATH:+:$LIBRARY_PATH}"
export LD_LIBRARY_PATH="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# export CPPFLAGS="-I$DEPS_DST/include "
# export CFLAGS="$CPPFLAGS"
# export LDFLAGS="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"


export CC="/opt/gcc-indiff/bin/gcc"
export CXX="/opt/gcc-indiff/bin/g++"
export CPPFLAGS="-I$DEPS_DST/include"
export LDFLAGS="-L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} -fuse-ld=mold"
export ACLOCAL_PATH=/usr/share/aclocal:${ACLOCAL_PATH:-}

git clone --filter=blob:none --depth 1 https://github.com/cyrusimap/cyrus-sasl.git
cd cyrus-sasl
autoreconf -fi
./configure --with-openssl="$DEPS_DST" --prefix="$DEPS_DST"
make -j$(nproc)
make install
cd ..
unset CPPFLAGS
unset LDFLAGS


          
# yum install pkgconfig -y
# git clone --filter=blob:none --depth 1 https://git.openldap.org/openldap/openldap.git
# cd openldap
wget https://openldap.org/software/download/OpenLDAP/openldap-release/openldap-2.6.9.tgz
tar -xzf openldap-2.6.9.tgz
cd openldap-2.6.9
OPENLADP_DIR=$(pwd)
# git submodule update --init --recursive
#autoreconf -fi
mkdir obj
cd obj
env CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ CPPFLAGS="-I$DEPS_DST/include " \
    CFLAGS="-I$DEPS_DST/include -I$OPENLADP_DIR/include \
 -I$OPENLADP_DIR/servers/slapd \
 -I$OPENLADP_DIR/servers/lloadd \
 -I$OPENLADP_DIR/clients/tools" \
    LDFLAGS="-L$DEPS_DST/lib -fuse-ld=mold  -Wl,--strip-all -Wl,--gc-sections " \
    ../configure --prefix=$DEPS_DST --with-cyrus-sasl --with-tls="openssl" \
    --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu --target=x86_64-pc-linux-gnu \
    --enable-mdb \
    --enable-dynamic \
    --enable-modules \
    --enable-versioning \
    --enable-slapd \
    --enable-overlays \
    --enable-debug \
    --enable-syslog \
    --enable-accesslog \
    --enable-rlookups \
    --enable-crypt \
    --enable-lmpasswd \
    --enable-spasswd \
    --enable-homedir=mod \
    --enable-memberof=mod \
    --enable-refint=mod \
    --enable-syncprov=mod \
    --enable-balancer=mod \
    --with-pic \
    --with-gnu-ld
# env LDFLAGS="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++  \
make depend
make -j$(nproc) LDAP_INC="-I$OPENLADP_DIR/include \
 -I$OPENLADP_DIR/servers/slapd \
 -I$OPENLADP_DIR/servers/lloadd \
 -I$OPENLADP_DIR/clients/tools"
make install


if [[ -z "$PERCONA_BRANCH" ]]; then
    git clone --filter=blob:none --depth 1 https://github.com/percona/percona-server.git -b 8.0 /workspace/server
else
    git clone --filter=blob:none --depth 1 https://github.com/percona/percona-server.git -b $PERCONA_BRANCH /workspace/server
fi

cd /workspace/server
git submodule update --init --recursive

# Fix: buffered_error_log.h uses std::string but does not include <string>
sed -i '/#include <cstring>/a #include <string>' mysys/buffered_error_log.h

# build persona mysql
# mkdir -p /workspace/server/build /workspace/boost
# git clone --filter=blob:none --depth 1 https://github.com/boostorg/boost.git /workspace/boost
# cd /workspace/boost
# git submodule update --init --recursive

# wget https://archives.boost.io/release/1.87.0/source/boost_1_87_0.tar.bz2
boost_version_str="boost_1_87_0"
# wget https://archives.boost.io/release/1.87.0/source/${boost_version_str}.tar.bz2
mkdir -p /tmp/boost
# tar -xjf ${boost_version_str}.tar.bz2 -C /tmp/boost --strip-components=1


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

# 自带的有 patchs
cat /workspace/server/cmake/boost.cmake

mkdir /workspace/server/build
cd /workspace/server/build

# 避免外部 protobuf 干扰
unset PROTOC
export PKG_CONFIG_PATH=$DEPS_DST/lib/pkgconfig:$PKG_CONFIG_PATH
# -DPROTOBUF_PROTOC_LIBRARY="$DEPS_DST/lib/$PROTOC_LIB_BASENAME"  \
# -DPROTOBUF_PROTOC_EXECUTABLE="$VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME"  \
# 临时修复方案
# cp /opt/gcc-indiff/include/c++/16/bits/intcmp.h /opt/gcc-indiff/include/c++/16/bits/intcmp.h.bak
# sed -i 's/\bin_range\b/__in_range/g' /opt/gcc-indiff/include/c++/16/bits/intcmp.h
#     -DCMAKE_CXX_FLAGS="-std=c++20 -include cstdint -include cstddef -I$DEPS_DST/include -O2 -pipe -fPIC -DPIC -march=native -Wno-aligned-new -Wno-implicit-fallthrough -Wno-int-in-bool-context -Wno-shift-negative-value -Wno-misleading-indentation -Wno-format-overflow -Wno-nonnull -Wno-unused-function  " \
# -include cstdint -include cstddef 
# -fuse-ld=mold


rsync -a /opt/vcpkg/installed/x64-linux/include/ /opt/percona80/include/
rsync -a /opt/vcpkg/installed/x64-linux-dynamic/include/ /opt/percona80/include/
cmake .. -G Ninja \
    -DCMAKE_C_FLAGS="-include stdint.h -include stddef.h -D__NO_STRING_INLINES -I$DEPS_DST/include  -O2 -pipe -fPIC -DPIC " \
    -DCMAKE_CXX_FLAGS="-Uin_range -include string -include memory -include cstdint -include cstddef -D__NO_STRING_INLINES -I$DEPS_DST/include -O2 -pipe -fPIC -DPIC -Wno-error " \
    -DCMAKE_PREFIX_PATH="$DEPS_DST" \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DST" \
    -DCMAKE_EXE_LINKER_FLAGS="-L/opt/vcpkg/installed/x64-linux/lib -L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl " \
    -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DCMAKE_MODULE_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DCMAKE_TOOLCHAIN_FILE="/opt/vcpkg/scripts/buildsystems/vcpkg.cmake" \
    -DVCPKG_TARGET_TRIPLET="x64-linux" \
    -DWITH_COMPONENT_KEYRING_VAULT=ON \
    -DBUILD_CONFIG=mysql_release \
    -DWITH_PACKAGE_FLAGS=OFF \
    -DWITH_PROTOBUF=bundled \
    -DWITH_BOOST="/tmp/boost" -DDOWNLOAD_BOOST=1 \
    -DMYSQL_MAINTAINER_MODE=OFF \
    -DWITH_ROCKSDB=ON \
    -DWITH_MECAB=OFF \
    -DWITH_LIBEVENT=system \
    -DWITH_ZLIB=system \
    -DWITH_CURL=system \
    -DWITH_FIDO=bundled \
    -DWITH_RAPIDJSON=system -DWITH_EDITLINE=bundled \
    -DWITH_EXT_BACKTRACE=OFF \
    -DWITH_LZ4=system -DWITH_ZSTD=system -DWITH_SNAPPY=system -DWITH_JEMALLOC=system \
    -DWITH_SSL=system -DOPENSSL_ROOT_DIR="$DEPS_DST/include" -DOPENSSL_USE_STATIC_LIBS=ON \
    -DOPENSSL_SSL_LIBRARY="$DEPS_DST/lib/libssl.so" \
    -DOPENSSL_CRYPTO_LIBRARY="$DEPS_DST/lib/libcrypto.so" \
    -DWITH_ICU=system \
    -DWITH_SYSTEM_LIBS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib:$ORIGIN/../lib64' \
    -DCMAKE_BUILD_RPATH='/opt/gcc-indiff/lib64:$ORIGIN/../lib:$ORIGIN/../lib64' \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
    -DWITH_AUTHENTICATION_LDAP=OFF \
    -DWITH_PAM=ON \
    -DWITH_TESTS=0 \
    -DWITH_XPLUGIN_TESTS=0 \
    -DALLOW_NO_SSE42=ON \
    -DWITH_PERCONA_AUTHENTICATION_LDAP=OFF \
    -DWITH_ROUTER=OFF \
    -DWITH_UNIT_TESTS=OFF \
    -DWITH_NUMA=OFF \
    -DWITH_NDB=OFF \
    -DWITH_NDBCLUSTER=OFF \
    -DWITH_NDB_JAVA=OFF \
    -DWITH_PERFORMANCE_SCHEMA=ON -DWITH_PSI=ON -DWITH_MYISAM=ON -DENABLE_PSI=1 -DHAVE_PSI_INTERFACE=1 \
    -DWITH_ARCHIVE_STORAGE_ENGINE=OFF \
    -DWITH_BLACKHOLE_STORAGE_ENGINE=OFF \
    -DWITH_EXAMPLE_STORAGE_ENGINE=ON \
    -DWITH_FEDERATED_STORAGE_ENGINE=OFF \
    -DWITH_INNODB_MEMCACHED=ON \
    -DWITH_DOCS=OFF -DWITH_MAN_PAGES=OFF -DMYSQL_SERVER_SUFFIX="-indiff"

cmake -LAH -N . | tee /workspace/cmake-cache-vars-centos7.txt

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

zip -r -q -9 /workspace/percona80-centos7-x86_64-$(date +'%Y%m%d_%H%M').xz .

# free memory
free -h