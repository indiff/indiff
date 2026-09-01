#!/bin/bash
# author: indiff
# AliSQL build script for Oracle Linux 7
# Adapted from mariadb-build.sh for AliSQL (MySQL 8.0.44 branch)
# Build philosophy: vcpkg-managed system libs + gcc-indiff toolchain + mold linker
set -xe

# ============================================================================
# Locate protoc from vcpkg (AliSQL/MySQL 8.0 X Plugin may need protobuf)
# ============================================================================
find /opt/vcpkg/installed -name "*.so*"
find /opt/vcpkg/installed -name "*.a*"

PROTOC_BASENAME=$(basename $(find /opt/vcpkg/installed/x64-linux-dynamic/tools/protobuf -maxdepth 1 -name "protoc-*" | head -1))
LIBPROTOBUF_BASENAME=libprotobuf.so
chmod +x /opt/vcpkg/installed/x64-linux-dynamic/tools/protobuf/${PROTOC_BASENAME}

# ============================================================================
# Clone AliSQL source (https://github.com/alibaba/AliSQL)
# AliSQL is a MySQL 8.0.44 branch maintained by Alibaba Cloud Database Team
# Supports branch override via ALISQL_BRANCH env var
# ============================================================================
if [[ -z "$ALISQL_BRANCH" ]]; then
    git clone --filter=blob:none --depth 1 https://github.com/alibaba/AliSQL.git server
else
    git clone --filter=blob:none --depth 1 https://github.com/alibaba/AliSQL.git -b $ALISQL_BRANCH server
fi
cd server
git submodule update --init --recursive || true

# ============================================================================
# Dependency sync: copy vcpkg headers/libs + gcc-indiff + ICU to install prefix
# This mirrors the mariadb-build.sh approach: all deps consolidated under
# $ALISQL_INSTALL_PREFIX so the final tarball is self-contained.
# ============================================================================
DEPS_SRC="$VCPKG_ROOT/installed/x64-linux"
DEPS_DST="$ALISQL_INSTALL_PREFIX"
mkdir -p "$DEPS_DST"/{include,lib,lib64,tools}

# sync ICU (MySQL 8.0 / AliSQL unicode support)
rsync -a "/usr/local/icu/include/" "$DEPS_DST/include/" || true
rsync -a "/usr/local/icu/lib/"    "$DEPS_DST/lib/"    || true

# sync static triplet (x64-linux) headers and libs
rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a --copy-links "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true
rsync -a --copy-links "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true
rsync -a --copy-links "$DEPS_SRC/tools/protobuf/"    "$DEPS_DST/tools/"    || true

# sync dynamic triplet (x64-linux-dynamic) headers and libs
DEPS_SRC="$VCPKG_ROOT/installed/x64-linux-dynamic"
rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a --copy-links "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true
rsync -a --copy-links "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true
rsync -a --copy-links "$DEPS_SRC/tools/protobuf/"    "$DEPS_DST/tools/"    || true

# sync gcc-indiff toolchain headers and libs
rsync -a "/opt/gcc-indiff/include/" "$DEPS_DST/include/"
rsync -a --copy-links "/opt/gcc-indiff/lib64/"    "$DEPS_DST/lib64/"    || true

# sync jemalloc from build host if present
if [ -f /lib64/libjemalloc.so.1 ]; then
    echo "Found /lib64/libjemalloc.so.1 on build host, copying to $DEPS_DST/lib64"
    mkdir -p "$DEPS_DST/lib64"
    cp -a /lib64/libjemalloc.so* "$DEPS_DST/lib64/" || true
    chmod 644 "$DEPS_DST/lib64"/libjemalloc.so* 2>/dev/null || true
fi

# sync pkgconfig files
for d in lib lib64; do
    [[ -d "$DEPS_DST/$d/pkgconfig" ]] || mkdir -p "$DEPS_DST/$d/pkgconfig"
    rsync -a "$DEPS_SRC/$d/pkgconfig/" "$DEPS_DST/$d/pkgconfig/" 2>/dev/null || true
done

# ============================================================================
# Build environment setup (vcpkg + gcc-indiff + mold)
# ============================================================================
export TRIPLET=x64-linux-dynamic
VCPKG_PREFIX="${VCPKG_ROOT}/installed/${TRIPLET}"
export PKG_CONFIG_PATH="${VCPKG_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
export CPPFLAGS="-I${VCPKG_PREFIX}/include"
export LDFLAGS="-L/opt/gcc-indiff/lib64 -L${DEPS_DST}/lib -L${VCPKG_PREFIX}/lib -Wl,-rpath=${VCPKG_PREFIX}/lib,${DEPS_DST}/lib,/opt/gcc-indiff/lib64 -fuse-ld=mold"
export LD_LIBRARY_PATH="${VCPKG_PREFIX}/lib:${DEPS_DST}/lib:/opt/gcc-indiff/lib64"

# Lock gcc-indiff compiler globally
export CC="/opt/gcc-indiff/bin/gcc"
export CXX="/opt/gcc-indiff/bin/g++"
export CPPFLAGS="-I$DEPS_DST/include"
export LDFLAGS="-L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH} -fuse-ld=mold"
export ACLOCAL_PATH=/usr/share/aclocal:${ACLOCAL_PATH:-}

# Note: AliSQL (MySQL 8.0) does NOT require cyrus-sasl build.
# MySQL 8.0 has built-in authentication plugins (caching_sha2_password, etc.)
# and does not depend on external SASL for LDAP auth in the same way MariaDB does.

# ============================================================================
# Dependency tree snapshot for debugging
# ============================================================================
tree "$DEPS_DST"/{include,lib,lib64} > /workspace/deps_alisql_tree.txt

# ============================================================================
# Download Boost 1.77.0 (required by MySQL 8.0.44 / AliSQL)
# AliSQL build.sh expects: -DWITH_BOOST="extra/boost/boost_1_77_0"
# ============================================================================
# mkdir -p /workspace/server/extra/boost
# cd /workspace/server/extra/boost
# if [ ! -d boost_1_77_0 ]; then
#     curl -sLo boost_1_77_0.tar.bz2 https://boostorg.jfrog.io/artifactory/main/release/1.77.0/source/boost_1_77_0.tar.bz2 || \
#     curl -sLo boost_1_77_0.tar.bz2 https://sourceforge.net/projects/boost/files/boost/1.77.0/boost_1_77_0.tar.bz2/download
#     tar -xjf boost_1_77_0.tar.bz2
#     rm -f boost_1_77_0.tar.bz2
# fi

cd /opt/
git clone https://github.com/facebook/jemalloc.git --depth 1
cd jemalloc
sed -i 's/std::__throw_bad_alloc()/throw std::bad_alloc()/g' src/jemalloc_cpp.cpp
sh autogen.sh
env CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ ./configure --prefix="$DEPS_DST"
make -j$(nproc)
make install

cd /workspace/server

# ============================================================================
# AliSQL CMake configuration
#
# Key differences from MariaDB build:
# 1. FORCE_INSOURCE_BUILD=ON (AliSQL build.sh uses in-source cmake .)
# 2. INSTALL_LAYOUT=STANDALONE (MySQL 8.0 layout)
# 3. WITH_ZLIB=bundled, WITH_ZSTD=bundled, WITH_TIRPC=bundled (per AliSQL build.sh)
# 4. -D_GLIBCXX_USE_CXX11_ABI=0 (per AliSQL build.sh x86_64 flags)
# 5. No RocksDB (AliSQL uses InnoDB + DuckDB storage engines)
# 6. No cyrus-sasl (MySQL 8.0 built-in auth)
# 7. Boost 1.77.0 in extra/boost/boost_1_77_0
# 8. Storage engines: InnoDB, MyISAM, CSV, Archive, Blackhole, Federated, PerfSchema, TempTable
# ============================================================================

# CMake/ld search paths for vcpkg deps copied to install prefix
export CMAKE_PREFIX_PATH="$DEPS_DST${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export CMAKE_LIBRARY_PATH="$DEPS_DST/lib:$DEPS_DST/lib64${CMAKE_LIBRARY_PATH:+:$CMAKE_LIBRARY_PATH}"
export CMAKE_INCLUDE_PATH="$DEPS_DST/include${CMAKE_INCLUDE_PATH:+:$CMAKE_INCLUDE_PATH}"
export PKG_CONFIG_PATH="/usr/lib64/pkgconfig:/usr/share/pkgconfig:$DEPS_DST/lib/pkgconfig:$DEPS_DST/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"

# Link-time search paths
export LIBRARY_PATH="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LIBRARY_PATH:+:$LIBRARY_PATH}"
export LD_LIBRARY_PATH="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# build duckdb
# cd /workspace/server/extra/duckdb
# BUILD_EXTENSIONS='autocomplete;icu;json;tpch' GEN=ninja make -j`nproc` bundle-library
# rm -rf /workspace/server/extra/duckdb/build/CMakeCache.txt /workspace/server/extra/duckdb/build/CMakeFiles
# ls -lh /workspace/server/extra/duckdb/build/release/libduckdb_bundle.a

mkdir /workspace/server/build
cd /workspace/server/build
# 在 cmake 配置前执行

# 避免外部 protobuf 干扰
# unset PROTOC
# rm -rf /workspace/server/CMakeCache.txt /workspace/server/CMakeFiles
# rm -rf CMakeCache.txt CMakeFiles
# cmake .. -G Ninja \
#     -DFORCE_INSOURCE_BUILD=ON \
#     -DCMAKE_INSTALL_PREFIX=$DEPS_DST \
#     -DMYSQL_DATADIR="$DEPS_DST/data" \
#     -DSYSCONFDIR="$DEPS_DST" \
#     -DCMAKE_BUILD_TYPE=RelWithDebInfo \
#     -DMINIMAL_RELWITHDEBINFO=0 \
#     -DINSTALL_LAYOUT=STANDALONE \
#     -DMYSQL_MAINTAINER_MODE=0 \
#     -DWITH_DEBUG=OFF \
#     -DENABLE_GCOV=OFF \
#     -DWITH_EXTRA_CHARSETS=all \
#     -DDEFAULT_CHARSET=utf8mb4 \
#     -DDEFAULT_COLLATION=utf8mb4_0900_ai_ci \
#     -DENABLED_PROFILING=1 \
#     -DENABLED_LOCAL_INFILE=1 \
#     -DWITH_UNIT_TESTS=0 \
#     -DWITH_DOCS=OFF \
#     -DCMAKE_C_FLAGS=" -D__NO_STRING_INLINES -D_GLIBCXX_USE_CXX11_ABI=0 -I$DEPS_DST/include -O2 -march=native -fno-strict-aliasing -fexceptions -fno-omit-frame-pointer -D_GLIBCXX_USE_CXX11_ABI=0  " \
#     -DCMAKE_CXX_FLAGS=" -include cstdint -include cstddef -D__NO_STRING_INLINES -D_GLIBCXX_USE_CXX11_ABI=0 -I$DEPS_DST/include -O2 -march=native -fno-strict-aliasing -fexceptions -fno-omit-frame-pointer -D_GLIBCXX_USE_CXX11_ABI=0 " \
#     -DCMAKE_EXE_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl -fuse-ld=mold" \
#     -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl -fuse-ld=mold" \
#     -DCMAKE_MODULE_LINKER_FLAGS="-L/usr/lib64 -L/opt/gcc-indiff/lib64 -L$DEPS_DST/lib -L$DEPS_DST/lib64 -Wl,--strip-all -Wl,--gc-sections -Wl,--no-as-needed -ldl -fuse-ld=mold" \
#     -DCMAKE_INSTALL_RPATH='$ORIGIN/../lib64:$ORIGIN/../lib' \
#     -DCMAKE_BUILD_RPATH='$ORIGIN/../lib64:$ORIGIN/../lib' \
#     -DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON \
#     -DWITH_BOOST="extra/boost/boost_1_77_0" \
#     -DWITH_ZLIB=system \
#     -DWITH_ZSTD=system \
#     -DWITH_TIRPC=bundled \
#     -DWITH_LZ4=system \
#     -DWITH_SNAPPY=system \
#     -DWITH_JEMALLOC=system \
#     -DWITH_EDITLINE=bundled \
#     -DWITH_SSL=system -DOPENSSL_ROOT_DIR="$DEPS_DST" \
#     -DWITH_CURL=system \
#     -DWITH_PROTOBUF=system \
#     -DPROTOBUF_INCLUDE_DIR="$DEPS_DST/include" \
#     -DPROTOBUF_LIBRARY="$DEPS_DST/lib/$LIBPROTOBUF_BASENAME" \
#     -DPROTOBUF_PROTOC_EXECUTABLE="$VCPKG_ROOT/installed/x64-linux-dynamic/tools/protobuf/$PROTOC_BASENAME" \
#     -DPROTOBUF_PROTOC_LIBRARY="/opt/vcpkg/installed/x64-linux-dynamic/lib/libprotoc.so" \
#     -DPROTOBUF_LITE_LIBRARY="/opt/vcpkg/installed/x64-linux-dynamic/lib/libprotobuf-lite.so" \
#     -DWITH_RAPIDJSON=system \
#     -DWITH_MYISAM_STORAGE_ENGINE=1 \
#     -DWITH_INNOBASE_STORAGE_ENGINE=1 \
#     -DWITH_CSV_STORAGE_ENGINE=1 \
#     -DWITH_ARCHIVE_STORAGE_ENGINE=1 \
#     -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
#     -DWITH_FEDERATED_STORAGE_ENGINE=1 \
#     -DWITH_PERFSCHEMA_STORAGE_ENGINE=1 \
#     -DWITH_EXAMPLE_STORAGE_ENGINE=0 \
#     -DWITH_TEMPTABLE_STORAGE_ENGINE=1 \
#     -DWITH_ASAN=OFF \
#     -DWITH_TSAN=OFF \
#     -DMYSQL_SERVER_SUFFIX="-indiff"

# ============================================================================
# Build and install with Ninja
# ============================================================================
# cmake --build . -j"$(nproc)" --target install
# cmake --install .

# ============================================================================
# Post-install cleanup: remove test suites, debug binaries, static libs
# ============================================================================




# ============================================================================
# 2. Inject version from tag into MYSQL_VERSION (8.0 branch) or VERSION (5.7)
# ============================================================================
cd /workspace/server
VERSION_FILE=""
for f in MYSQL_VERSION VERSION; do
    [ -f "$f" ] && VERSION_FILE="$f" && break
done
if [ -z "$VERSION_FILE" ]; then
    echo "ERROR: neither MYSQL_VERSION nor VERSION found in source root" >&2
    exit 1
fi
sed -i \
    -e "s/^MYSQL_VERSION_MAJOR=.*/MYSQL_VERSION_MAJOR=${MAJOR}/" \
    -e "s/^MYSQL_VERSION_MINOR=.*/MYSQL_VERSION_MINOR=${MINOR}/" \
    -e "s/^MYSQL_VERSION_PATCH=.*/MYSQL_VERSION_PATCH=${PATCH}/" \
    -e "s/^MYSQL_VERSION_EXTRA=.*/MYSQL_VERSION_EXTRA=-${EXTRA}/" \
    "$VERSION_FILE"
echo "--- ${VERSION_FILE} after injection ---"
cat "$VERSION_FILE"

# ============================================================================
# 3. Limit DuckDB parallel build jobs (match official CI)
# ============================================================================
MAX_JOBS="$(nproc 2>/dev/null || true)"
if [ -z "$MAX_JOBS" ]; then
    MAX_JOBS="$(grep -c '^processor[[:space:]]*:' /proc/cpuinfo 2>/dev/null || true)"
fi
if ! [[ "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]]; then
    MAX_JOBS=2
fi
if [ "$MAX_JOBS" -gt 32 ]; then
    MAX_JOBS=32
fi
export MAX_JOBS
echo "DuckDB build jobs: ${MAX_JOBS}"

if [ -f extra/duckdb/Makefile ] && \
   grep -Eq '^[[:space:]]*cmake --build \. --config Release -j ' \
     extra/duckdb/Makefile; then
  sed -i -E \
    "s#(^[[:space:]]*cmake --build \\. --config Release -j) .+#\\1 ${MAX_JOBS}#" \
    extra/duckdb/Makefile
  if ! grep -Eq \
    "^[[:space:]]*cmake --build \\. --config Release -j ${MAX_JOBS}[[:space:]]*$" \
    extra/duckdb/Makefile; then
    echo "ERROR: failed to limit DuckDB release build parallelism" >&2
    exit 1
  fi
fi

export CC=/opt/gcc-indiff/bin/gcc
export CXX=/opt/gcc-indiff/bin/g++
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib:$LD_LIBRARY_PATH

sh build.sh -t release -d "$ALISQL_INSTALL_PREFIX"
make install

# ============================================================================
# 5. Package final artifact (same naming as official releases)
#    alisql-${VER}-linux-glibc2.17-${ARCH}.tar.xz
# ============================================================================
INSTALL_BASE="$(basename "$ALISQL_INSTALL_PREFIX")"
INSTALL_PARENT="$(dirname "$ALISQL_INSTALL_PREFIX")"
cd "$INSTALL_PARENT"
GLIBC="glibc$(ldd --version | awk 'NR==1{print $NF}')"
ARCH="$(uname -m)"
PKG="alisql-${VER}-linux-${GLIBC}-${ARCH}.tar.xz"
TOPDIR="${PKG%.tar.xz}"

# ============================================================================
# Package final artifact
# ============================================================================
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
zip -r -q -9 /workspace/alisql-centos7-x86_64-$(date +'%Y%m%d_%H%M').zip .

# XZ_OPT='-T0 -9' tar -cJf "${OUT_DIR}/${PKG}" \
#   --transform="s,^${INSTALL_BASE},${TOPDIR}," \
#   --exclude="${INSTALL_BASE}/mysql-test" \
#   --exclude="${INSTALL_BASE}/run" \
#   --exclude="${INSTALL_BASE}/var" \
#   --exclude="${INSTALL_BASE}/LICENSE-test" \
#   --exclude="${INSTALL_BASE}/LICENSE.router" \
#   --exclude="${INSTALL_BASE}/README-test" \
#   --exclude="${INSTALL_BASE}/README.router" \
#   --exclude="${INSTALL_BASE}/mysqlrouter-log-rotate" \
#   "${INSTALL_BASE}/"
# ls -lh "${OUT_DIR}/${PKG}"

# free memory
free -h

