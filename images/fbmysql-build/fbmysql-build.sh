#!/bin/bash
# author: indiff
set -xe

PROTOC_BASENAME=$(basename $VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/protoc-*)
PROTOC_LIB_BASENAME=$(basename $VCPKG_ROOT/installed/x64-linux-dynamic/lib/libprotoc.so.*)
chmod +x "$VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME"
# wget https://archives.boost.io/release/1.89.0/source/boost_1_89_0.tar.bz2
# mkdir -p /tmp/boost
# tar -xjf boost_1_89_0.tar.bz2 -C /tmp/boost --strip-components=1
wget https://archives.boost.io/release/1.77.0/source/boost_1_77_0.tar.bz2
# wget  https://boostorg.jfrog.io/artifactory/main/release/1.77.0/source/boost_1_77_0.tar.bz2
mkdir -p /tmp/boost
tar -xjf boost_1_77_0.tar.bz2 -C /tmp/boost --strip-components=1

if [[ -z "$FBMYSQL_BRANCH" ]]; then
  git clone --filter=blob:none --depth 1 https://github.com/facebook/mysql-5.6.git server
else
  git clone --filter=blob:none --depth 1 https://github.com/facebook/mysql-5.6.git -b $FBMYSQL_BRANCH server
fi

cd server
git submodule update --init --recursive


# patch zlib.h
sed -i '1i#ifndef Z_ARG\n#define Z_ARG(args) args\n#endif\n' extra/zlib/zlib-1.2.13/zlib.h || true

DEPS_SRC="$VCPKG_ROOT/installed/x64-linux"
DEPS_DST="$FBMYSQL_INSTALL_PREFIX"
mkdir -p "$DEPS_DST"/{include,lib,lib64,tools}

# sync icu68
rsync -a "/usr/local/icu68/include/" "$DEPS_DST/include/"
rsync -a "/usr/local/icu68/lib/"    "$DEPS_DST/lib64/"    || true

# 2) 复制头文件与动态库（.so 与 .so.*）及 pkgconfig
rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a --copy-links "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true
rsync -a --copy-links "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true
rsync -a --copy-links "$DEPS_SRC/tools/protobuf/"    "$DEPS_DST/tools/"    || true

DEPS_SRC="$VCPKG_ROOT/installed/x64-linux-dynamic"

rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a --copy-links "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true
rsync -a --copy-links "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true
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

# 显示一下目录接口查看是否存在相关的 lib 和 include
# tree "$DEPS_DST"/{include,lib,lib64} | tee /workspace/deps_dst_tree.txt
tree "$DEPS_DST"/{include,lib,lib64} > /workspace/deps_dst_tree.txt

# build persona mysql
mkdir -p /workspace/server/build /workspace/server/boost
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
unset PROTOC
cmake .. -G Ninja \
    -DCMAKE_INSTALL_PREFIX=$DEPS_DST \
    -DCMAKE_C_FLAGS="-I$DEPS_DST/include -O2 -pipe -fPIC -DPIC -Wno-implicit-fallthrough -Wno-int-in-bool-context -Wno-shift-negative-value -Wno-misleading-indentation -Wno-format-overflow -Wno-nonnull -Wno-unused-function " \
    -DCMAKE_CXX_FLAGS="-include cstdint -include cstddef -I$DEPS_DST/include -O2 -pipe -fPIC -DPIC -march=native -Wno-aligned-new -Wno-implicit-fallthrough -Wno-int-in-bool-context -Wno-shift-negative-value -Wno-misleading-indentation -Wno-format-overflow -Wno-nonnull -Wno-unused-function  " \
    -DCMAKE_CXX_EXTENSIONS=OFF \
    -DENABLE_DTRACE=0 \
    -DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DCMAKE_MODULE_LINKER_FLAGS="-L/usr/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DDEFAULT_CHARSET="utf8mb4" \
    -DDEFAULT_COLLATION="utf8mb4_bin" \
    -DWITH_BOOST="/tmp/boost" \
    -DWITH_TESTS=0 \
    -DWITH_BENCHMARK_TOOLS=0 \
    -DWITH_GFLAGS=0 \
    -DWITH_NDB=OFF \
    -DWITH_LTO=ON \
    -DWITH_MYSQLX=0 \
    -DWITH_NDB_JAVA=0 \
    -DWITH_RAPID=0 \
    -DWITH_ROUTER=0 \
    -DWITH_UNIT_TESTS=0 \
    -DWITH_ROCKSDB=ON \
    -DWITH_INNODB_MEMCACHED=ON \
    -DWITH_CURL=system \
    -DWITH_LIBEVENT=system \
    -DWITH_ZLIB=system -DWITH_LZ4=system -DWITH_ZSTD=system -DWITH_SNAPPY=system \
    -DWITH_PROTOBUF=system  \
    -DPROTOBUF_PROTOC_LIBRARY="$DEPS_DST/lib/$PROTOC_LIB_BASENAME"  \
    -DPROTOBUF_PROTOC_EXECUTABLE="$VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME"  \
    -DWITH_ICU=system  \
    -DWITH_SSL=system -DOPENSSL_ROOT_DIR="$DEPS_DST" \
    -DWITH_FIDO=system \
    -DWITH_MECAB=OFF \
    -DWITH_EXT_BACKTRACE=OFF \
    -DWITH_NUMA=OFF \
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
zip -r -q -9 /workspace/fbmysql-centos7-x86_64-$FBMYSQL_BRANCH-$(date +'%Y%m%d_%H%M').xz .

# free memory
free -h
# sync
# echo 3 > /proc/sys/vm/drop_caches
# free -h && df -h
