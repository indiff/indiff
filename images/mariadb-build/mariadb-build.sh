#!/bin/bash
# author: indiff
set -xe

find /opt/vcpkg/installed -name "*.so*"
find /opt/vcpkg/installed -name "*.a*"
PROTOC_BASENAME=$(basename $(find /opt/vcpkg/installed/x64-linux-dynamic/tools/protobuf -maxdepth 1 -name "protoc-*" | head -1))
#PROTOC_LIB_BASENAME=$(basename $(find /opt/vcpkg/installed/x64-linux-dynamic/lib -maxdepth 1 -name "libprotoc*.so*" | head -1))
LIBPROTOBUF_BASENAME=libprotobuf.so
chmod +x /opt/vcpkg/installed/x64-linux-dynamic/tools/protobuf/${PROTOC_BASENAME}

if [[ -z "$MARIADB_BRANCH" ]]; then
    git clone --filter=blob:none --depth 1 https://github.com/MariaDB/server.git server
else
    git clone --filter=blob:none --depth 1 https://github.com/MariaDB/server.git  -b $MARIADB_BRANCH server
fi

cd server
git submodule update --init --recursive


DEPS_SRC="$VCPKG_ROOT/installed/x64-linux"
DEPS_DST="$MARIADB_INSTALL_PREFIX"
mkdir -p "$DEPS_DST"/{include,lib,lib64,tools}

# sync icu
rsync -a "/usr/local/icu/include/" "$DEPS_DST/include/" || true
rsync -a "/usr/local/icu/lib/"    "$DEPS_DST/lib/"    || true

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


# export CFLAGS="-Wall "
# 固定变量，和你现有环境对齐
 export TRIPLET=x64-linux-dynamic
 VCPKG_PREFIX="${VCPKG_ROOT}/installed/${TRIPLET}"
 # 导入vcpkg全套编译环境
 export PKG_CONFIG_PATH="${VCPKG_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
 export CPPFLAGS="-I${VCPKG_PREFIX}/include"
 # 正确LDFLAGS：所有库目录加-L，追加rpath保证运行时找到动态库
 export LDFLAGS="-L/opt/gcc-indiff/lib64 -L${DEPS_DST}/lib -L${VCPKG_PREFIX}/lib -Wl,-rpath=${VCPKG_PREFIX}/lib,${DEPS_DST}/lib,/opt/gcc-indiff/lib64 -fuse-ld=mold"
 export LD_LIBRARY_PATH="${VCPKG_PREFIX}/lib:${DEPS_DST}/lib:/opt/gcc-indiff/lib64"
 # 统一锁定gcc-indiff编译器，全程全局生效
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



# 显示一下目录接口查看是否存在相关的 lib 和 include
# tree "$DEPS_DST"/{include,lib,lib64} | tee /workspace/deps_dst_tree.txt
tree "$DEPS_DST"/{include,lib,lib64} > /workspace/deps_mariadb_tree.txt

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
# -D__NO_STRING_INLINES
unset PROTOC
cmake .. -G Ninja \
    -DCMAKE_INSTALL_PREFIX=$DEPS_DST \
    -DCMAKE_C_FLAGS=" -D__NO_STRING_INLINES -I$DEPS_DST/include  -O2 -march=native " \
    -DCMAKE_CXX_FLAGS="-std=c++20 -include cstdint -include cstddef -D__NO_STRING_INLINES -I$DEPS_DST/include  -O2 -march=native " \
    -DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DCMAKE_MODULE_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl" \
    -DWITH_BOOST=boost -DDOWNLOAD_BOOST=1 -DWITH_BOOST=../boost \
    -DWITH_LTO=ON \
    -DBUILD_CONFIG="mysql_release" \
    -DCMAKE_BUILD_TYPE="Release" \
    -DWITH_DEBUG=0 -DENABLE_GCOV=0 -DWITH_ASAN=0 -DWITH_TSAN=0 -DINSTALL_LAYOUT=STANDALONE -DWITH_EMBEDDED_SERVER=0 -DWITH_EXTRA_CHARSETS=all -DWITH_UNIT_TESTS=0 \
    -DDEFAULT_CHARSET="utf8mb4" \
    -DDEFAULT_COLLATION="utf8mb4_0900_ai_ci" \
    -DENABLED_LOCAL_INFILE=1 \
    -DPLUGIN_ROCKSDB=YES \
    -DWITH_ROCKSDB=ON \
    -DWITH_CURL=system \
    -DWITH_LZ4=system -DWITH_ZSTD=system -DWITH_SNAPPY=system -DWITH_JEMALLOC=system \
    -DWITH_SSL=system -DOPENSSL_ROOT_DIR="$DEPS_DST" \
    -DWITH_PROTOBUF=system \
    -DPROTOBUF_INCLUDE_DIR="$DEPS_DST/include" \
    -DPROTOBUF_LIBRARY="$DEPS_DST/lib/$LIBPROTOBUF_BASENAME" \
    -DPROTOBUF_PROTOC_EXECUTABLE="$VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME"  \
    -DPROTOBUF_PROTOC_LIBRARY="/opt/vcpkg/installed/x64-linux-dynamic/lib/libprotoc.so" \
    -DPROTOBUF_LITE_LIBRARY="/opt/vcpkg/installed/x64-linux-dynamic/lib/libprotobuf-lite.so" \
    -DWITH_RAPIDJSON=system -DWITH_EDITLINE=bundled \
    -DMYSQL_MAINTAINER_MODE=OFF \
    -DWITH_SAFEMALLOC=OFF \
    -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib64:$ORIGIN/../lib' \
    -DCMAKE_BUILD_RPATH='$ORIGIN/../lib64:$ORIGIN/../lib' \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
    -DWITH_AUTHENTICATION_LDAP=ON \
    -DWITH_UNIT_TESTS=OFF \
    -DCONC_WITH_{UNITTEST,SSL}=OFF \
    -DWITH_TESTS=0 \
    -DWITH_XPLUGIN_TESTS=0 \
    -DWITH_DOCS=OFF -DWITH_MAN_PAGES=OFF -DMYSQL_SERVER_SUFFIX="-indiff"

# cmake .. -LH | tee /workspace/cmake-cache-vars-omysql-centos7.txt

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


cat > "$DEPS_DST/start.sh" << 'OUTER_EOF'
rm -f /opt/mariadb/my.cnf
sleep 5

cat > /opt/mariadb/my.cnf << 'INNER_EOF'
[mysqld]
basedir=/opt/mariadb
datadir=/opt/mariadb/data
pid-file=/opt/mariadb/run/mysqld.pid
log-error=/opt/mariadb/log/error.log
socket=/opt/mariadb/data/mariadb.sock
user=mariadb
general-log
innodb_based_binlog = ON
innodb_flush_log_at_trx_commit=1
log_bin = mariadb-bin
binlog_format = ROW
port=3306
default-storage-engine=InnoDB
character_set_server=UTF8MB4
skip-external-locking
server-id = 1
lower-case-table-names=1
max_connections = 100
max_connect_errors = 100
open_files_limit = 65535
plugin-load-add=ha_rocksdb.so
INNER_EOF

groupdel mariadb 2>/dev/null || true
userdel -r mariadb 2>/dev/null || true
groupadd --system mariadb
useradd -r -s /sbin/nologin mariadb -g mariadb

rm -rf /opt/mariadb/{data,log,run,tmp}
mkdir -p /opt/mariadb/{data,log,run,tmp}
touch /opt/mariadb/log/error.log
chown -R mariadb:mariadb /opt/mariadb
chmod 700 /opt/mariadb/data

/opt/mariadb/scripts/mariadb-install-db --defaults-file=/opt/mariadb/my.cnf --user=mariadb

chown -R mariadb:mariadb /opt/mariadb

/opt/mariadb/bin/mariadbd-safe --defaults-file='/opt/mariadb/my.cnf' --user=mariadb >/dev/null 2>&1 &

sleep 3
/opt/mariadb/bin/mysql --protocol=socket --socket=/opt/mariadb/data/mariadb.sock -uroot -e "
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'Admin001';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
"

echo "启动成功"
OUTER_EOF

zip -r -q -9 /workspace/mariadb-centos7-x86_64-$(date +'%Y%m%d_%H%M').xz .

# free memory
free -h
# sync
# echo 3 > /proc/sys/vm/drop_caches
# free -h && df -h