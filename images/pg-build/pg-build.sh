#!/bin/bash
# author: indiff
set -xe


DEPS_SRC="/opt/vcpkg/installed/x64-linux"
DEPS_DST="${INSTALL_PREFIX}"
mkdir -p  "$DEPS_DST"/{include,lib,share}
rsync -a  --copy-links "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a  --copy-links "$DEPS_SRC/lib/" "$DEPS_DST/lib/" || true

DEPS_SRC="/opt/vcpkg/installed/${VCPKG_TRIPLET}"
DEPS_DST="${INSTALL_PREFIX}"
rsync -a  --copy-links "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a  --copy-links "$DEPS_SRC/lib/" "$DEPS_DST/lib/" || true
rsync -a  --copy-links "$DEPS_SRC/share/" "$DEPS_DST/share/" || true
# rsync -a  --copy-links "$DEPS_SRC/lib64/" "$DEPS_DST/lib64/" || true
for d in lib lib64; do
if [ -d "$DEPS_SRC/$d/pkgconfig" ]; then
    mkdir -p "$DEPS_DST/$d/pkgconfig"
    rsync -a  --copy-links "$DEPS_SRC/$d/pkgconfig/" "$DEPS_DST/$d/pkgconfig/"
fi
done


# install icu  
wget https://github.com/unicode-org/icu/releases/download/release-68-2/icu4c-68_2-src.tgz
tar -xzf icu4c-68_2-src.tgz
cd icu/source
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH:-""}
LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:$DEPS_DST/lib:$LD_LIBRARY_PATH
./configure --prefix=/usr/local/icu68
make -j$(nproc)
make install
rsync -a  --copy-links "/usr/local/icu68/include/" "$DEPS_DST/include/"
rsync -a  --copy-links "/usr/local/icu68/lib/"    "$DEPS_DST/lib/"    || true
# rsync -a "/usr/local/icu68/lib/"    "$DEPS_DST/lib64/"    || true
cd ../..

# 2) 复制头文件与动态库（.so 与 .so.*）及 pkgconfig
rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a --copy-links "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true
rsync -a --copy-links "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true
# rsync -a --copy-links "$DEPS_SRC/tools/protobuf/"    "$DEPS_DST/tools/"    || true

cp -r $DEPS_DST/include/libxml2/libxml $DEPS_DST/include/libxml || true
tree $DEPS_DST

# PostgreSQL
git clone --depth 1 -b "${PG_VERSION_TAG}" https://github.com/postgres/postgres.git postgresql
cd postgresql
mkdir build && cd build
export CPPFLAGS="-I${DEPS_DST}/include"
export CXXFLAGS="-I${DEPS_DST}/include"
export CFLAGS="-I${DEPS_DST}/include"
export LDFLAGS="-L${DEPS_DST}/lib -Wl,-rpath,'\$ORIGIN/../lib:${DEPS_DST}/lib'"
export LZ4_CFLAGS="-I${DEPS_DST}/include"
export LZ4_LIBS="-L${DEPS_DST}/lib -llz4"
export PKG_CONFIG_PATH=${DEPS_DST}/lib/pkgconfig:${DEPS_DST}/share/pkgconfig
pkg-config --cflags --libs libxslt

../configure \
    --prefix="${DEPS_DST}" \
    --with-openssl \
    --with-lz4 \
    --with-zstd \
    ZSTD_CFLAGS="-I${DEPS_DST}/include" \
    ZSTD_LIBS="-L${DEPS_DST}/lib -lzstd" \
    --with-libxml \
    --with-libxslt \
    LIBXSLT_CFLAGS="-I${DEPS_DST}/include" \
    LIBXSLT_LIBS="-L${DEPS_DST}/lib -lxslt -lxml2 " \
    --with-icu \
    ICU_CFLAGS="-I${DEPS_DST}/include" \
    ICU_LIBS="-L${DEPS_DST}/lib -licui18n -licuuc -licudata" \
    --with-pam \
    --with-system-tzdata=/usr/share/zoneinfo \
    --enable-nls='zh'
    --with-readline || cat config.log

#--enable-thread-safety
# make world-bin
make world-bin -j"$(nproc)"
make install
cd ../..

# TimescaleDB
export PATH="${DEPS_DST}/bin:$PATH"
# git clone --depth 1 -b "${TIMESCALEDB_VERSION}" https://github.com/timescale/timescaledb.git
# git clone --depth 1 --filter=blob:none https://github.com/timescale/timescaledb.git
# cd timescaledb
# sed -E -i 's/OR[[:space:]]*\([[:space:]]*\$\{PG_VERSION_MAJOR\}[[:space:]]+GREATER[[:space:]]+"17"[[:space:]]*\)/OR (\${PG_VERSION_MAJOR} GREATER "20")/g' CMakeLists.txt
# sed -E -i 's/OR[[:space:]]*\([[:space:]]*\$\{PG_VERSION_MAJOR\}[[:space:]]+GREATER[[:space:]]+"18"[[:space:]]*\)/OR (\${PG_VERSION_MAJOR} GREATER "20")/g' CMakeLists.txt
# sed -E -i 's/OR[[:space:]]*\([[:space:]]*\$\{PG_VERSION_MAJOR\}[[:space:]]+GREATER[[:space:]]+"19"[[:space:]]*\)/OR (\${PG_VERSION_MAJOR} GREATER "20")/g' CMakeLists.txt

# ./bootstrap -DCMAKE_BUILD_TYPE=Release -DAPACHE_ONLY=1 -DPG_CONFIG="${DEPS_DST}/bin/pg_config"
# cd build
# make -j"$(nproc)"
# make install
# cd ../..
git clone --depth 1 --filter=blob:none https://github.com/libgeos/geos.git
cd geos
mkdir build
cd build
CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ cmake -DCMAKE_C_COMPILER=/opt/gcc-indiff/bin/gcc -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=NO -DBUILD_DOCUMENTATION=NO -DCMAKE_INSTALL_LIBDIR=${DEPS_DST}/lib -DCMAKE_INSTALL_BINDIR=${DEPS_DST}/bin -DCMAKE_INSTALL_INCLUDEDIR=${DEPS_DST}/include  ..
cmake --build . -j $(nproc)
cmake --build . -j $(nproc)  --target install
cd ../..

# PostGIS
export PKG_CONFIG_PATH="${DEPS_DST}/lib/pkgconfig:${DEPS_DST}/lib64/pkgconfig:${PKG_CONFIG_PATH}"
git clone --depth 1 -b "${POSTGIS_VERSION_TAG}" https://github.com/postgis/postgis.git
cd postgis
./autogen.sh
./configure \
    --with-pgconfig="${DEPS_DST}/bin/pg_config" \
    --with-geosconfig="${DEPS_DST}/bin/geos-config" \
    --with-projdir="${DEPS_DST}" \
    --without-protobuf \
    --with-gdalconfig="${DEPS_DST}/bin/gdal-config" || true
make -j"$(nproc)"
make install
cd ..

# 精简 & 打包
cd "${DEPS_DST}"
find . -type f -name "*.a" -delete || true
find bin -type f -exec file {} \; | awk -F: '/ELF/{print $1}' | xargs -r strip --strip-unneeded 2>/dev/null || true
find lib -maxdepth 1 -type f -name "*.so*" -exec strip --strip-unneeded {} + 2>/dev/null || true
# RPATH（可选）
command -v patchelf >/dev/null 2>&1 && for f in lib/postgresql/*.so; do patchelf --set-rpath "\$ORIGIN:${DEPS_DST}/lib" "$f" || true; done

# tar -C /opt -czf /workspace/postgresql-centos7-x86_64-$(date +'%Y%m%d_%H%M').tar.gz postgresql
zip -r -q -9 ../pg-indiff-centos7-x86_64-$(date +'%Y%m%d_%H%M').zip .
tree . > /workspace/pg-centos7-tree-$(date +'%Y%m%d_%H%M').txt
sync
echo 3 > /proc/sys/vm/drop_caches || true
