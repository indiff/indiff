#!/bin/bash
# author: indiff
set -xe



PROTOC_BASENAME=$(basename $VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/protoc-*)
PROTOC_LIB_BASENAME=$(basename $VCPKG_ROOT/installed/x64-linux-dynamic/lib/libprotoc.so.*)
chmod +x $VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME
git clone --filter=blob:none --depth 1 https://github.com/mysql/mysql-server.git  -b $MYSQL_BRANCH server
cd server
# git submodule update --init --recursive
# wget https://archives.boost.io/release/1.89.0/source/boost_1_89_0.tar.bz2
# cp boost_1_89_0.tar.bz2 extra/boost/
# grep -n 'BOOST_PACKAGE_NAME' cmake/boost.cmake || true
# sed -i 's/^SET(BOOST_PACKAGE_NAME.*)$/SET(BOOST_PACKAGE_NAME "boost_1_89_0")/' cmake/boost.cmake
# grep -n 'BOOST_PACKAGE_NAME' cmake/boost.cmake

sed -i '/^[[:space:]]*#include[[:space:]]*<vector>[[:space:]]*$/a #include <cstdint>' extra/libcno/cno_huffman_generator.cc
# patch fix /workspace/server/strings/collations_internal.cc:553:22: error: no matching function for call t
# sed -i 's/hash\.find(\s*\(key\)\s*)/hash.find(std::to_string(\1))/g' /workspace/server/strings/collations_internal.cc
sed -i 's/enum class Gtid_format : uint8_t {/enum Gtid_format {/g' /workspace/server/libs/mysql/gtid/gtid_format.h
cd ..

DEPS_SRC="$VCPKG_ROOT/installed/x64-linux"
DEPS_DST="$INSTALL_PREFIX"
mkdir -p "$DEPS_DST"/{include,lib,lib64,tools}

# sync icu  
rsync -a "/usr/local/icu68/include/" "$DEPS_DST/include/"
rsync -a "/usr/local/icu68/lib/"    "$DEPS_DST/lib64/"    || true
cd ../..

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
tree "$DEPS_DST"/{include,lib,lib64} | tee /workspace/deps_dst_tree.txt

# build persona mysql
mkdir -p server/build server/boost
cd server/build

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
unset PROTOC
cmake .. -G Ninja \
-DCMAKE_INSTALL_PREFIX=$DEPS_DST \
-DCMAKE_C_FLAGS="-I$DEPS_DST/include -O3 -g -pipe -fPIC -DPIC " \
-DCMAKE_CXX_FLAGS="-include cstdint -include cstddef -I$DEPS_DST/include -O3 -g -pipe -fPIC -DPIC -march=native " \
-DCMAKE_CXX_EXTENSIONS=OFF \
-DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--no-as-needed -ldl" \
-DCMAKE_SHARED_LINKER_FLAGS="-L/usr/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--no-as-needed -ldl" \
-DCMAKE_MODULE_LINKER_FLAGS="-L/usr/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--no-as-needed -ldl" \
-DDEFAULT_CHARSET="utf8mb4" \
-DDEFAULT_COLLATION="utf8mb4_bin" \
-DFORCE_INSOURCE_BUILD=ON \
-DCMAKE_BUILD_TYPE="Release" \
-DMYSQL_MAINTAINER_MODE=0 \
-DENABLED_LOCAL_INFILE=1 \
-DENABLE_DTRACE=0 \
-DWITH_GFLAGS=OFF \
-DWITH_TOOLS=OFF \
-DWITH_BENCHMARK_TOOLS=OFF \
-DWITH_CORE_TOOLS=OFF \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_ARCHIVE_STORAGE_ENGINE=OFF \
-DWITH_BLACKHOLE_STORAGE_ENGINE=OFF \
-DWITH_FEDERATED_STORAGE_ENGINE=OFF \
-DWITH_EXAMPLE_STORAGE_ENGINE=ON \
-DWITH_INNODB_MEMCACHED=ON \
-DWITH_ROUTER=OFF \
-DWITH_BOOST="/workspace/server/extra/boost/boost_1_87_0" \
-DDISABLE_PSI_COND=1 \
-DDISABLE_PSI_DATA_LOCK=1 \
-DDISABLE_PSI_ERROR=1 \
-DDISABLE_PSI_FILE=1 \
-DDISABLE_PSI_IDLE=1 \
-DDISABLE_PSI_MEMORY=1 \
-DDISABLE_PSI_METADATA=1 \
-DDISABLE_PSI_MUTEX=1 \
-DDISABLE_PSI_PS=1 \
-DDISABLE_PSI_RWLOCK=1 \
-DDISABLE_PSI_SOCKET=1 \
-DDISABLE_PSI_SP=1 \
-DDISABLE_PSI_STAGE=0 \
-DDISABLE_PSI_STATEMENT=1 \
-DDISABLE_PSI_STATEMENT_DIGEST=1 \
-DDISABLE_PSI_TABLE=1 \
-DDISABLE_PSI_THREAD=0 \
-DDISABLE_PSI_TRANSACTION=1 \
-DWITH_MYSQLX=OFF \
-DWITH_NDB=OFF \
-DWITH_CNO=OFF \
-DMSVC_CPPCHECK=OFF \
-DMAX_INDEXES=128 \
-DWITH_AUTHENTICATION_LDAP=OFF \
-DWITH_LTO=ON \
-DWITH_MYSQLX=0 -DWITH_NDBCLUSTER_STORAGE_ENGINE=OFF -DWITH_NDBMTD=OFF \
-DWITH_LDAP=OFF -DWITH_SASL=OFF \
-DWITH_EXT_BACKTRACE=OFF \
-DWITH_LSAN=OFF -DWITH_ASAN=OFF -DWITH_TSAN=OFF -DWITH_UBSAN=OFF -DWITH_DEBUG=OFF -DWITH_LOCK_ORDER=OFF -DENABLED_PROFILING=OFF -DWITH_NUMA=OFF \
-DWITH_KERBEROS=none \
-DWITH_FIDO=none \
-DWITH_NDB_JAVA=0 \
-DWITH_RAPID=0 \
-DWITH_ROUTER=0 \
-DWITH_UNIT_TESTS=0 \
-DWITH_ICU=system \
-DWITH_PROTOBUF=system  \
-DPROTOBUF_PROTOC_LIBRARY="$DEPS_DST/lib/$PROTOC_LIB_BASENAME"  \
-DPROTOBUF_PROTOC_EXECUTABLE="$VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME"  \
-DWITH_LIBEVENT=system -DWITH_LZ4=system -DWITH_ZLIB=system -DWITH_ZSTD=system \
-DCMAKE_INSTALL_RPATH='$ORIGIN/../lib64:$ORIGIN/../lib' \
-DCMAKE_BUILD_RPATH='$ORIGIN/../lib64:$ORIGIN/../lib' \
-DWITH_DOCS=OFF -DWITH_MAN_PAGES=OFF

cmake .. -LH | tee /workspace/cmake-cache-vars-omysql-centos7.txt

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
zip -r -q -9 /workspace/omysql-centos7-x86_64-$(date +'%Y%m%d_%H%M').xz .

# free memory
free -h
sync
echo 3 > /proc/sys/vm/drop_caches
free -h && df -h

