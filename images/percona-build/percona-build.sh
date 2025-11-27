#!/bin/bash
# author: indiff
set -xe



TRIPLET=x64-linux
DEPS_SRC="$VCPKG_ROOT/installed/$TRIPLET"
DEPS_DST="$PERCONA_INSTALL_PREFIX"
## use lld-indiff
curl -#Lo lld-indiff.zip "https://github.com/indiff/gcc-build/releases/download/20251126_1903_16.0.0/lld-indiff-centos7-x86_64-20251126_1903.xz"
unzip lld-indiff.zip -d /opt/gcc-indiff
export LD_LIBRARY_PATH="/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib:$LD_LIBRARY_PATH"
ln -sf /opt/gcc-indiff/bin/ld.lld /usr/bin/ld.lld
/opt/gcc-indiff/gcc -fuse-ld=lld -Wl,--version -xc - <<< 'int main(){return 0;}'
export LDFLAGS="-fuse-ld=lld"

mkdir -p "$DEPS_DST"/{include,lib,lib64}




DEPS_SRC="$VCPKG_ROOT/installed/x64-linux"
# sync icu68
rsync -a "/usr/local/icu68/include/" "$DEPS_DST/include/"
rsync -a "/usr/local/icu68/lib/"    "$DEPS_DST/lib64/"    || true

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
  
git clone --filter=blob:none --depth 1 https://github.com/cyrusimap/cyrus-sasl.git
cd cyrus-sasl
# sh autogen.sh
# export CFLAGS="-Wall "
./autogen.sh --with-openssl="$DEPS_DST" --prefix="$DEPS_DST"
    # --with-staticsasl
env LDFLAGS="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} -fuse-ld=lld" CC="/opt/gcc-indiff/bin/gcc" CXX="/opt/gcc-indiff/bin/g++" \
make install || true
# make -j$(nproc)
# make install
cd ..

# 克隆官方仓库（或镜像）
git clone https://github.com/autotools-mirror/autoconf.git
cd autoconf
./bootstrap     # 如果存在
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..

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
wget https://ftp.gnu.org/gnu/automake/automake-1.18.1.tar.gz
tar -xzf automake-1.18.1.tar.gz
cd automake-1.18.1
./bootstrap     # 如果存在
./configure --prefix=$PREFIX_DIR
make -j$(nproc)
make install
cd ..


# insatll libtool
# git clone --depth=1 https://https.git.savannah.gnu.org/git/libtool.git
wget http://mirrors.tencent.com/gnu/libtool/libtool-2.5.4.tar.gz
tar -xzf libtool-2.5.4.tar.gz
cd libtool-2.5.4
./bootstrap  --force     # 如果存在
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..

wget https://ftp.gnu.org/gnu/m4/m4-1.4.20.tar.gz
tar -xzf m4-1.4.20.tar.gz
cd m4-1.4.20
env CC=/opt/gcc-indiff/bin/gcc CFLAGS="-I/opt/mygcc/include " \
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..
m4 --version
          
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
    LDFLAGS="-L$DEPS_DST/lib -fuse-ld=lld " \
    ../configure --prefix=$DEPS_DST --with-cyrus-sasl --with-tls="openssl" \
    --build=x86_64-pc-linux-gnu --host=x86_64-pc-linux-gnu --target=x86_64-pc-linux-gnu \
    --enable-mdb \
    --enable-dynamic \
    --enable-modules \
    --enable-versioning \
    --enable-slapd \
    --enable-overlays \
    --enable-debug \
    --enable-syslog  \
    --enable-accesslog \
    --enable-rlookups \
    --enable-crypt \
    --enable-lmpasswd \
    --enable-spasswd \
    --enable-homedir=mod \
    --enable-memberof=mod  \
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

# build persona mysql
mkdir -p /workspace/server/build /workspace/server/boost
cd /workspace/server/build

# 避免外部 protobuf 干扰
unset PROTOC
export PKG_CONFIG_PATH=$DEPS_DST/lib/pkgconfig:$PKG_CONFIG_PATH
# -DPROTOBUF_PROTOC_LIBRARY="$DEPS_DST/lib/$PROTOC_LIB_BASENAME"  \
# -DPROTOBUF_PROTOC_EXECUTABLE="$VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME"  \
cmake .. -G Ninja \
    -DCMAKE_C_FLAGS="-I$DEPS_DST/include " \
    -DCMAKE_CXX_FLAGS="-I$DEPS_DST/include " \
    -DCMAKE_PREFIX_PATH="$DEPS_DST/lib" \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DST" \
    -DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -fuse-ld=lld -Wl,--no-as-needed -ldl " \
    -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--no-as-needed -ldl" \
    -DCMAKE_MODULE_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--no-as-needed -ldl" \
    -DWITH_BOOST=boost -DDOWNLOAD_BOOST=1 -DWITH_BOOST=../boost \
    -DWITH_ROCKSDB=ON \
    -DWITH_LZ4=system -DWITH_ZSTD=system -DWITH_SNAPPY=system -DWITH_JEMALLOC=system \
    -DWITH_SSL=system -DOPENSSL_ROOT_DIR="$DEPS_DST" \
    -DWITH_ICU=system \
    -DWITH_PROTOBUF=bundled  \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib:$ORIGIN/../lib64' \
    -DCMAKE_BUILD_RPATH='/opt/gcc-indiff/lib64:$ORIGIN/../lib:$ORIGIN/../lib64' \
    -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
    -DWITH_AUTHENTICATION_LDAP=ON \
    -DWITH_PAM=ON \
    -DWITH_INNODB_MEMCACHED=1 \
    -DWITH_UNIT_TESTS=0 \
    -DWITH_TESTS=0 \
    -DWITH_XPLUGIN_TESTS=0 \
    -DWITH_NUMA=1 \
    -DALLOW_NO_SSE42=ON \
    -DWITH_DOCS=OFF -DWITH_MAN_PAGES=OFF -DMYSQL_SERVER_SUFFIX="-indiff"

cmake -LAH -N . | tee /workspace/cmake-cache-vars-centos7.txt

# Ninja 默认详细，便于定位真实失败点
# 只会编译并安装最终产物(不会编译 tests)  [3343/4756]
cmake --build . -j"$(nproc)" --target install
cmake --install .

cd $DEPS_DST
rm -rf $DEPS_DST/man
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


