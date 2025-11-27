#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# CentOS 7 dependency installation and configuration script
set -xe
echo 'LANG=zh_CN.UTF-8' >> /etc/environment
echo 'LANGUAGE=zh_CN.UTF-8' >> /etc/environment
echo 'LC_ALL=zh_CN.UTF-8' >> /etc/environment
echo 'LC_CTYPE=zh_CN.UTF-8' >> /etc/environment

# Define mirror list for CentOS 7.9.2009
MIRRORS=(
    "http://mirror.rackspace.com/centos-vault/7.9.2009"
    "https://mirror.nsc.liu.se/centos-store/7.9.2009"
    "https://linuxsoft.cern.ch/centos-vault/7.9.2009"
    "https://archive.kernel.org/centos-vault/7.9.2009"
    "https://vault.centos.org/7.9.2009"
)

# Initialize variables
FASTEST_MIRROR=""
FASTEST_TIME=99999

echo "Testing mirror response times..."

# Test each mirror's response time
for MIRROR in "${MIRRORS[@]}"; do
    echo -n "Testing $MIRROR ... "
    TIME=$(curl -o /dev/null -s -w "%{time_total}\n" "$MIRROR" || echo "99999")
    echo "$TIME seconds"
    
    if (( $(echo "$TIME < $FASTEST_TIME" | bc -l) )); then
        FASTEST_TIME=$TIME
        FASTEST_MIRROR=$MIRROR
    fi
done

echo "-----------------------------------"
echo "Fastest mirror: $FASTEST_MIRROR"
echo "Response time: $FASTEST_TIME seconds"

# Configure YUM repositories
echo "[base]" > /etc/yum.repos.d/CentOS-Base.repo
echo "name=CentOS-Base" >> /etc/yum.repos.d/CentOS-Base.repo
echo "baseurl=${FASTEST_MIRROR}/os/\$basearch/" >> /etc/yum.repos.d/CentOS-Base.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo

echo "[updates]" >> /etc/yum.repos.d/CentOS-Base.repo
echo "name=CentOS-updates" >> /etc/yum.repos.d/CentOS-Base.repo
echo "baseurl=${FASTEST_MIRROR}/updates/\$basearch/" >> /etc/yum.repos.d/CentOS-Base.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo

echo "[extras]" >> /etc/yum.repos.d/CentOS-Base.repo
echo "name=CentOS-extras" >> /etc/yum.repos.d/CentOS-Base.repo
echo "baseurl=${FASTEST_MIRROR}/extras/\$basearch/" >> /etc/yum.repos.d/CentOS-Base.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo

echo "[centosplus]" >> /etc/yum.repos.d/CentOS-Base.repo
echo "name=CentOS-centosplus" >> /etc/yum.repos.d/CentOS-Base.repo
echo "baseurl=${FASTEST_MIRROR}/centosplus/\$basearch/" >> /etc/yum.repos.d/CentOS-Base.repo
echo "gpgcheck=0" >> /etc/yum.repos.d/CentOS-Base.repo

yum clean all
yum makecache
yum install -y https://dl.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm

# Set timezone
yum -y install tzdata
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone

# Update system
yum update -y


yum clean all
yum install -y https://dl.fedoraproject.org/pub/archive/epel/7/x86_64/Packages/e/epel-release-7-14.noarch.rpm || true
yum makecache fast

yum -y install tzdata
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo 'Asia/Shanghai' > /etc/timezone
yum update -y
yum install -y flex bison ncurses-dev texinfo gcc gperf patch libtool automake g++ libncurses5-dev gawk subversion expat libexpat1-dev binutils-dev bc libcap-dev autoconf libgmp-dev build-essential pkg-config libmpc-dev libmpfr-dev autopoint gettext txt2man liblzma-dev mercurial wget tar cmake zstd ninja-build make pkgconfig xz xz-devel glibc-devel.i686 which lld bzip2 glibc glibc-devel
yum install -y pcre-devel zlib-devel make git wget sed perl-IPC-Cmd GeoIP GeoIP-devel zip systemd automake libtool
yum install -y perl-Test-Simple perl-FindBin perl-IPC-Cmd perl-Text-Template perl-File-Compare perl-File-Copy perl-Data-Dumper perl-Time-Piece
yum -y install autoconf autoconf-archive wget automake libtool m4 pkgconfig pam-devel

# 基础依赖
yum install -y zip unzip rsync ninja-build curl wget tar xz unzip bzip2 which rsync tree pkgconfig \
make cmake3 gcc gcc-c++ flex bison gettext \
autoconf automake libtool patchelf \
readline-devel \
perl-ExtUtils-Embed tree

# Install development tools and dependencies
yum groupinstall -y "Development tools"
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
yum clean all



# install cmake v4.1.1
curl -sLo cmake3.tar.gz https://github.com/Kitware/CMake/releases/download/v4.1.1/cmake-4.1.1-linux-x86_64.tar.gz
tar -xzf cmake3.tar.gz
mv cmake-4.1.1-linux-x86_64 /opt/cmake
rm -f /usr/bin/cmake
ln -sf /opt/cmake/bin/cmake /usr/bin/cmake

# update git
yum -y remove git
yum -y install https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
yum -y install git
curl -s https://packagecloud.io/install/repositories/orchardit/general/script.rpm.sh | bash
yum -y install python37-3.7.6-1.el7.x86_64
python --version

# build ninja 
curl -sLo /opt/gcc-indiff.zip "${gcc_indiff_centos7_url}"
unzip /opt/gcc-indiff.zip -d /opt/gcc-indiff
git clone --filter=blob:none https://github.com/ninja-build/ninja.git --depth=1
cd ninja
cmake -Bbuild-cmake -DBUILD_TESTING=OFF -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" -DCMAKE_BUILD_TYPE=release -DCMAKE_CXX_COMPILER=/opt/gcc-indiff/bin/g++
cmake --build build-cmake
rm -f /usr/bin/ninja
cp build-cmake/ninja /usr/bin/ninja
cd ..
rm -rf ninja

/usr/bin/ninja --version

# yum -y remove python36 python36-pip python36-devel python3 python3-pip python3-devel
# yum -y install yum-plugin-copr
# yum -y copr enable adrienverge/python37
# yum -y install python37 python37-devel python37-pip
python3 --version
          
git --version

# 创建符号链接

# Verify installations

make -v
cmake --version || true
ninja --version || true

export PATH=/opt/gcc-indiff/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib
export PATH=/opt/gcc-indiff/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib


export TRIPLET=x64-linux
export PATH=/opt/gcc-indiff/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib

CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ $VCPKG_ROOT/vcpkg install \
            zlib \
            zstd \
            --triplet x64-linux --clean-after-build	|| cat $VCPKG_ROOT/installed/vcpkg/issue_body.md || true
            
CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ $VCPKG_ROOT/vcpkg install \
            openssl curl[core,non-http,ssl,openssl,zstd] jemalloc --triplet x64-linux-dynamic --clean-after-build || cat $VCPKG_ROOT/installed/vcpkg/issue_body.md || true
            
echo "CentOS 7 git-build environment setup completed successfully!"
