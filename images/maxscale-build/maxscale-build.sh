#!/bin/bash
# author: indiff
set -xe

export VCPKG_ROOT="${VCPKG_ROOT:-/opt/vcpkg}"

find /opt/vcpkg/installed -name "*.so*"
find /opt/vcpkg/installed -name "*.a*"


if [ ! -d MaxScale/.git ]; then
  if [[ -z "$MAXSCALE_BRANCH" ]]; then
    git clone --filter=blob:none --depth 1 https://github.com/mariadb-corporation/MaxScale.git MaxScale
  else
    git clone --filter=blob:none --depth 1 https://github.com/mariadb-corporation/MaxScale.git  -b $MAXSCALE_BRANCH MaxScale
  fi
fi

cd MaxScale
git submodule update --init --recursive


DEPS_SRC="$VCPKG_ROOT/installed/x64-linux"
DEPS_DST="/opt/maxscale"
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

# MaxScale links against the system unixODBC library (libodbc.so.2), but a plain
# CentOS 7 runtime host does not have unixODBC installed by default, which makes
# the packaged "maxscale" binary fail with "libodbc.so.2: cannot open shared
# object file". Bundle unixODBC's runtime libraries (and its libltdl.so.7
# dependency) from the build host so the package is self-contained and runs on
# a stock CentOS 7 system without extra package installs.
mkdir -p "$DEPS_DST/lib64"
for glob in 'libodbc.so*' 'libodbcinst.so*' 'libltdl.so.7*'; do
    for dir in /lib64 /usr/lib64; do
        # shellcheck disable=SC2231
        for f in $dir/$glob; do
            [ -e "$f" ] || continue
            cp -a "$f" "$DEPS_DST/lib64/" || true
        done
    done
done

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

if [ ! -d cyrus-sasl/.git ]; then
  git clone --filter=blob:none --depth 1 https://github.com/cyrusimap/cyrus-sasl.git
fi
cd cyrus-sasl
autoreconf -fi
./configure --with-openssl="$DEPS_DST" --prefix="$DEPS_DST"
make -j$(nproc)
make install
cd ..
unset CPPFLAGS
unset LDFLAGS


export CMAKE_POLICY_VERSION_MINIMUM=3.5
export NODE_OPTIONS=--openssl-legacy-provider


# build  MaxScale
cd /workspace/MaxScale/

mkdir -p /workspace/MaxScale/_build
cd /workspace/MaxScale/_build

# 供 CMake/ld 查找 vcpkg 拷贝到 /opt 的头文件与库
export CMAKE_PREFIX_PATH="$DEPS_DST${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export CMAKE_LIBRARY_PATH="$DEPS_DST/lib:$DEPS_DST/lib64${CMAKE_LIBRARY_PATH:+:$CMAKE_LIBRARY_PATH}"
export CMAKE_INCLUDE_PATH="$DEPS_DST/include${CMAKE_INCLUDE_PATH:+:$CMAKE_INCLUDE_PATH}"
export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/share/pkgconfig:$DEPS_DST/lib/pkgconfig:$DEPS_DST/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# 链接期搜索路径(关键修复 -ljemalloc not found)
export LIBRARY_PATH="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LIBRARY_PATH:+:$LIBRARY_PATH}"
export LD_LIBRARY_PATH="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

TCLSH_SHELL=$(which tclsh)

#     -DBUILD_SHARED_LIBS=OFF \
#     -DFORCE_BUNDLE=OFF \
#     -DBUNDLE=OFF \

# fix1 cmake patch
sed -i 's|BUILD_COMMAND make "CFLAGS=-fPIC -std=c11"|BUILD_COMMAND make "CFLAGS=-fPIC -std=c11 ${CMAKE_C_FLAGS}"|' /workspace/MaxScale/cmake/BuildLibKMIP.cmake

# fix2: launchpad.net/ftp.gnu.org are unreachable in this build environment, so the
# libmicrohttpd source hash is repointed to the equivalent 0.9.75 tarball mirrored on
# deb.debian.org (LIBMICROHTTPD_URLS is overridden below via -D on the cmake command line)
sed -i 's|URL_HASH SHA256=9e7023a151120060d2806a6ea4c13ca9933ece4eacfc5c9464d20edddb76b0a0|URL_HASH SHA256=796e7e217a4802679fcac667a4e98501c53185dcf50ca0583870e84192620131|' /workspace/MaxScale/cmake/BuildMicroHttpd.cmake

# fix3: hiredis's "make USE_SSL=1" doesn't know where the bundled openssl headers/libs
# live, so openssl/ssl.h can't be found. Point it at $DEPS_DST explicitly.
sed -i "s|BUILD_COMMAND make USE_SSL=1|BUILD_COMMAND make USE_SSL=1 CFLAGS=-I$DEPS_DST/include LDFLAGS=-L$DEPS_DST/lib|" /workspace/MaxScale/cmake/BuildHiredis.cmake

# fix4: the vendored pcre2's CMakeLists.txt requires CMake >= 3.5 in a way that is
# rejected outright by modern CMake unless CMAKE_POLICY_VERSION_MINIMUM is forwarded
# to its nested ExternalProject configure step as well.
sed -i 's|-DPCRE2_SUPPORT_JIT=Y|-DPCRE2_SUPPORT_JIT=Y -DCMAKE_POLICY_VERSION_MINIMUM=3.5|' /workspace/MaxScale/cmake/BuildPCRE2.cmake

# fix5: maxctrl's committed package-lock.json is missing the optional "fsevents"
# (macOS-only) entry, which makes the strict "npm ci" in newer npm releases fail
# with EUSAGE. "npm install" performs the same install without that strict check.
sed -i 's|COMMAND npm ci$|COMMAND npm install --no-audit --no-fund|' /workspace/MaxScale/maxctrl/CMakeLists.txt

# ls -la /opt/maxscale/lib/lib{k5crypto,krb5support,com_err}.a
#     -DGSSAPI_LIBS="/opt/maxscale/lib/libgssapi_krb5.a;/opt/maxscale/lib/libkrb5.a;/opt/maxscale/lib/libk5crypto.a;/opt/maxscale/lib/libkrb5support.a;/opt/maxscale/lib/libcom_err.a;resolv;dl;pthread" \
cmake .. -G "Unix Makefiles" \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DCMAKE_INSTALL_PREFIX="$DEPS_DST" \
    -DCMAKE_BUILD_TYPE="Release" \
    -DTCL_TCLSH="$TCLSH_SHELL" \
    -DCMAKE_TOOLCHAIN_FILE="/opt/vcpkg/scripts/buildsystems/vcpkg.cmake" \
    -DVCPKG_TARGET_TRIPLET="x64-linux-dynamic" \
    -DVCPKG_INSTALLED_DIR=/opt/vcpkg/installed \
    -DCMAKE_C_COMPILER=/opt/gcc-indiff/bin/gcc \
    -DCMAKE_CXX_COMPILER=/opt/gcc-indiff/bin/g++ \
    -DCMAKE_LIBRARY_PATH=/opt/gcc-indiff/lib64 \
    -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib64:$ORIGIN/../lib' \
    -DCMAKE_BUILD_RPATH='$ORIGIN/../lib64:$ORIGIN/../lib' \
    -DCMAKE_PREFIX_PATH=/opt/vcpkg/installed/x64-linux-dynamic \
    -DBoost_INCLUDE_DIR=/opt/vcpkg/installed/x64-linux-dynamic/include \
    -DZSTD_INCLUDE_DIR=/opt/vcpkg/installed/x64-linux-dynamic/include \
    -DZSTD_LIBRARIES=/opt/vcpkg/installed/x64-linux-dynamic/lib/libzstd.so \
    -DSQLITE_INCLUDE_DIR=/opt/vcpkg/installed/x64-linux-dynamic/include \
    -DSQLITE_LIBRARIES=/opt/vcpkg/installed/x64-linux-dynamic/lib/libsqlite3.so \
    -DPCRE2_INCLUDE_DIRS=/opt/vcpkg/installed/x64-linux-dynamic/include \
    -DPCRE2_LIBRARIES=/opt/vcpkg/installed/x64-linux-dynamic/lib/libpcre2-8.so \
    -DJANSSON_INCLUDE_DIR=/opt/vcpkg/installed/x64-linux-dynamic/include \
    -DJANSSON_LIBRARIES=/opt/vcpkg/installed/x64-linux-dynamic/lib/libjansson.so \
    -DLIBUUID_HEADERS=/opt/vcpkg/installed/x64-linux-dynamic/include \
    -DLIBUUID_LIBRARIES=/opt/vcpkg/installed/x64-linux-dynamic/lib/libuuid.so \
    -DNODEJS_EXECUTABLE=/opt/node-v26.8.1-linux-x64-glibc-217/bin/node \
    -DNPM_EXECUTABLE=/opt/node-v26.8.1-linux-x64-glibc-217/bin/npm \
    -DCMAKE_CXX_FLAGS="-isystem /opt/maxscale/include -isystem /opt/vcpkg/installed/x64-linux-dynamic/include" \
    -DCMAKE_C_FLAGS="-isystem /opt/maxscale/include -isystem /opt/vcpkg/installed/x64-linux-dynamic/include" \
    -DLIBSSH_LIBRARY=/opt/vcpkg/installed/x64-linux-dynamic/lib/libssh.so \
    -DLIBSSH_INCLUDE_DIR=/opt/vcpkg/installed/x64-linux-dynamic/include \
    -DLIBMEMCACHED_URL=https://deb.debian.org/debian/pool/main/libm/libmemcached/libmemcached_1.0.18.orig.tar.gz \
    -DLIBMICROHTTPD_URLS=https://deb.debian.org/debian/pool/main/libm/libmicrohttpd/libmicrohttpd_0.9.75.orig.tar.xz \
    -DBUILD_NOSQL=OFF \
    -DBUILD_TESTS=OFF \
    -DFORCE_BUNDLE=ON \
    -DHIREDIS_USE_SSL=OFF \
    -DWITH_SYSTEM_NODEJS=ON


# cmake .. -LH | tee /workspace/cmake-cache-vars-omysql-centos7.txt

# Ninja 默认详细，便于定位真实失败点
# 只会编译并安装最终产物(不会编译 tests)  [3343/4756]
cmake --build . -j"$(nproc)" --target install
cmake --install .

cd $DEPS_DST
zip -r -q -9 /workspace/maxscale-centos7-x86_64-$(date +'%Y%m%d_%H%M').xz .
ls -lh /workspace
free -h
