#!/bin/bash
# author: indiff
# Oracle Linux 7 dependency installation and configuration script
# Adapted from centos7.sh for AliSQL compilation on Oracle Linux 7
set -xe

echo 'LANG=zh_CN.UTF-8' >> /etc/environment
echo 'LANGUAGE=zh_CN.UTF-8' >> /etc/environment
echo 'LC_ALL=zh_CN.UTF-8' >> /etc/environment
echo 'LC_CTYPE=zh_CN.UTF-8' >> /etc/environment

# ============================================================================
# Oracle Linux 7 yum repository configuration
# Unlike CentOS 7 (EOL, requires vault mirrors), Oracle Linux 7 official
# repositories are still maintained. We enable optional & addons repos
# for additional development packages.
# ============================================================================

# Install yum-utils for yum-config-manager
yum install -y yum-utils

# Enable additional repositories
yum-config-manager --enable ol7_optional_latest || true
yum-config-manager --enable ol7_addons || true

# Software Collections repo for devtoolset-10 (matches official CI)
cat >/etc/yum.repos.d/ol7-scl.repo <<'REPO'
[ol7_software_collections]
name=Oracle Linux 7 Software Collections ($basearch)
baseurl=https://yum.oracle.com/repo/OracleLinux/OL7/SoftwareCollections/$basearch/
gpgcheck=1
enabled=1
gpgkey=https://yum.oracle.com/RPM-GPG-KEY-oracle-ol7
REPO
# Oracle EPEL
yum install -y oracle-epel-release-el7 || \
    yum install -y https://dl.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm || true

# Set timezone
yum -y install tzdata
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# Update system
yum clean all
yum makecache
yum update -y

# ============================================================================
# Base build tools and development libraries
# Package names are identical between CentOS 7 and Oracle Linux 7 (both RHEL-derived)
# ============================================================================
yum install -y flex bison ncurses-devel texinfo gcc gperf patch libtool \
    automake gcc-c++ gawk subversion expat expat-devel binutils-devel bc \
    libcap-devel autoconf gmp-devel gmp pkgconfig libmpc-devel mpfr-devel \
    autopoint gettext txt2man liblzma-devel mercurial wget tar cmake zstd \
    ninja-build make xz xz-devel glibc-devel.i686 which lld bzip2 glibc \
    glibc-devel

yum install -y pcre-devel zlib-devel make git wget sed perl-IPC-Cmd \
    GeoIP GeoIP-devel zip systemd automake libtool

yum install -y perl-Test-Simple perl-FindBin perl-IPC-Cmd perl-Text-Template \
    perl-File-Compare perl-File-Copy perl-Data-Dumper perl-Time-Piece

yum -y install autoconf autoconf-archive wget automake libtool m4 pkgconfig \
    pam-devel help2man

# 基础依赖
yum install -y zip unzip rsync ninja-build curl wget tar xz bzip2 which \
    tree pkgconfig make cmake3 gcc gcc-c++ flex bison gettext \
    autoconf automake libtool patchelf readline-devel \
    perl-ExtUtils-Embed libtirpc libtirpc-devel

# Install development tools group
yum groupinstall -y "Development tools" || true

yum install -y \
    mpfr-devel \
    gmp-devel \
    libmpc-devel \
    zlib-devel \
    glibc-devel.i686 \
    glibc-devel \
    binutils-devel \
    texinfo \
    bison \
    flex \
    cmake \
    which \
    ninja-build \
    lld \
    bzip2 \
    wget \
    tar \
    git \
    tree \
    ncurses-devel \
    expat-devel \
    pkgconfig \
    gettext-devel \
    xz \
    xz-devel \
    zstd \
    pcre-devel \
    make \
    sed \
    autoconf \
    automake \
    libtool \
    curl \
    file \
    zip

yum install -y systemd-devel libgudev1 || true

yum install -y wget \
devtoolset-10-gcc devtoolset-10-gcc-c++ devtoolset-10-binutils \
openssl openssl-devel ncurses-devel libaio-devel perl-IPC-Cmd bison

# ============================================================================
# Base build tools and development libraries
# ============================================================================
yum install -y \
    git wget \
    devtoolset-10-gcc devtoolset-10-gcc-c++ devtoolset-10-binutils \
    openssl openssl-devel ncurses-devel libaio-devel perl-IPC-Cmd bison \
    flex gperf patch libtool automake gcc gcc-c++ autoconf \
    pkgconfig make zstd ninja-build xz xz-devel which bzip2 \
    zip unzip rsync curl tar tree sed gawk bc \
    perl-ExtUtils-Embed perl-Data-Dumper perl-Time-Piece \
    readline-devel expat-devel zlib-devel systemd-devel libgudev1 \
    texinfo help2man
    
    
yum clean all

# ============================================================================
# Upgrade CMake to 4.4.0 (AliSQL requires CMake 3.x+, MySQL 8.0 needs 3.19+)
# ============================================================================
curl -sLo cmake3.tar.gz https://github.com/Kitware/CMake/releases/download/v4.4.0/cmake-4.4.0-linux-x86_64.tar.gz
tar -xzf cmake3.tar.gz
mv cmake-4.4.0-linux-x86_64 /opt/cmake
rm -f /usr/bin/cmake
ln -sf /opt/cmake/bin/cmake /usr/bin/cmake

# ============================================================================
# Upgrade git (Oracle Linux 7 ships old git; use endpointdev repo)
# ============================================================================
yum -y remove git
yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
yum -y install git

# ============================================================================
# Install gcc-indiff custom toolchain (RHEL7-compatible)
# ============================================================================
curl -sLo /opt/gcc-indiff.zip "${gcc_indiff_centos7_url}"
unzip /opt/gcc-indiff.zip -d /opt/gcc-indiff
ln -sf /opt/gcc-indiff/bin/ld.mold /usr/bin/ld.mold
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib
export LDOPTS="-fuse-ld=mold "

# ============================================================================
# Build ninja from source with gcc-indiff (static linking for portability)
# ============================================================================
git clone --filter=blob:none https://github.com/ninja-build/ninja.git --depth=1
cd ninja
cmake -Bbuild-cmake -DBUILD_TESTING=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
    -DCMAKE_BUILD_TYPE=release \
    -DCMAKE_CXX_COMPILER=/opt/gcc-indiff/bin/g++
cmake --build build-cmake
rm -f /usr/bin/ninja
cp build-cmake/ninja /usr/bin/ninja
cd ..
rm -rf ninja
/usr/bin/ninja --version

# ============================================================================
# Install autotools and build tools from source (newer versions than OL7 ships)
# ============================================================================
yum -y install autoconf autoconf-archive icu wget automake libtool m4 pkgconfig

# Install Python 3.7 (AliSQL requires Python 3; OL7 base ships Python 2.7)
yum -y remove python36 python36-pip python36-devel python3 python3-pip python3-devel || true
yum -y install yum-plugin-copr
yum -y copr enable adrienverge/python37 || true
yum -y install python37 python37-devel python37-pip || true
python3 --version || true

git --version

# Verify installations
make -v
cmake --version || true
ninja --version || true

export PATH=/opt/gcc-indiff/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib

# ============================================================================
# Bootstrap vcpkg for third-party dependency management
# ============================================================================
git clone --filter=blob:none --depth 1 https://github.com/microsoft/vcpkg.git /opt/vcpkg
/opt/vcpkg/bootstrap-vcpkg.sh
export VCPKG_ROOT=/opt/vcpkg
export PATH=/opt/gcc-indiff/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib
export TRIPLET=x64-linux

# ============================================================================
# Build autoconf / automake / libtool / m4 / pkg-config from source
# (newer versions needed for modern dependency builds)
# ============================================================================
yum install -y systemd-devel libgudev1 libgudev1-devel || true
yum install -y epel-release || true
yum install -y texinfo help2man patch

export CC="/opt/gcc-indiff/bin/gcc"
export CXX="/opt/gcc-indiff/bin/g++"
export ACLOCAL_PATH=/usr/share/aclocal:${ACLOCAL_PATH:-}

# autoconf from source
git clone https://github.com/autotools-mirror/autoconf.git
cd autoconf
./bootstrap     # if exists
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..

function wget_gnu(){
     local suffix=$1
     wget https://ftp.gnu.org/gnu/$suffix || wget https://mirrors.aliyun.com/gnu/$suffix || wget http://mirrors.tencent.com/gnu/$suffix
}

pkg-config --version || true

# pkg-config from source
wget https://pkgconfig.freedesktop.org/releases/pkg-config-0.29.2.tar.gz
tar xzf pkg-config-0.29.2.tar.gz
cd pkg-config-0.29.2
./configure --prefix=/usr --with-internal-glib
make CFLAGS="-Ubool -std=gnu11 -O2" -j$(nproc)
make install
pkg-config --version
cd ..

# automake from source
wget_gnu automake/automake-1.18.1.tar.gz
tar -xzf automake-1.18.1.tar.gz
cd automake-1.18.1
./bootstrap     # if exists
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..

# libtool from source
wget_gnu libtool/libtool-2.6.2.tar.gz
tar -xzf libtool-2.6.2.tar.gz
cd libtool-2.6.2
./bootstrap  --force     # if exists
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..

# m4 from source
wget_gnu m4/m4-latest.tar.gz
tar -xzf m4-latest.tar.gz
cd m4-*
env CC=/opt/gcc-indiff/bin/gcc CFLAGS="-I/opt/gcc-indiff/include " \
./configure --prefix=/usr
make -j$(nproc)
make install
cd ..
m4 --version

# ============================================================================
# vcpkg: install dynamic libraries (x64-linux-dynamic triplet)
# These are used at link time for AliSQL (MySQL 8.0) system library dependencies
# ============================================================================
CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ $VCPKG_ROOT/vcpkg install openssl curl[core,non-http,ssl,openssl,zstd] snappy \
            protobuf[core,libprotoc] \
            rapidjson \
            --triplet x64-linux-dynamic --clean-after-build \
            || cat /workspace/vcpkg/installed/vcpkg/issue_body.md

# ============================================================================
# vcpkg: install static libraries (x64-linux triplet)
# Compression, XML, event, regex libraries for AliSQL build
# ============================================================================
CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ $VCPKG_ROOT/vcpkg install \
            ncurses zlib \
            lz4 \
            zstd \
            bzip2 \
            lzo \
            libxml2 \
            libevent[openssl] \
            pcre2 \
            pkgconf mecab libaio libedit \
            --triplet $TRIPLET --clean-after-build \
            || cat /workspace/vcpkg/installed/vcpkg/issue_body.md

# ============================================================================
# Build ICU from source (needed by MySQL 8.0 / AliSQL unicode support)
# Installed to /usr/local/icu, synced to install prefix at build time
# ============================================================================
cd /opt
wget https://github.com/unicode-org/icu/releases/download/release-78.3/icu4c-78.3-sources.tgz
tar -xzf icu4c-78.3-sources.tgz
cd icu/source
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:$LD_LIBRARY_PATH
rm -rf /usr/local/icu || true
./configure --prefix=/usr/local/icu
make -j$(nproc)
make install

echo "Oracle Linux 7 AliSQL build environment setup completed successfully!"
