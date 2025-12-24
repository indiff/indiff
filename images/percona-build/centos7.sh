#!/bin/bash
# author: indiff
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
yum -y install autoconf autoconf-archive wget automake libtool m4 pkgconfig pam-devel help2man

# 基础依赖
yum install -y zip unzip rsync ninja-build curl wget tar xz unzip bzip2 which rsync tree pkgconfig \
make cmake3 gcc gcc-c++ flex bison gettext \
autoconf automake libtool patchelf \
readline-devel \
perl-ExtUtils-Embed tree libtirpc libtirpc-devel

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

# build ninja 
curl -sLo /opt/gcc-indiff.zip "${gcc_indiff_centos7_url}"
unzip /opt/gcc-indiff.zip -d /opt/gcc-indiff
ln -sf /opt/gcc-indiff/bin/ld.mold /usr/bin/ld.mold
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib
export LDOPTS="-fuse-ld=mold "

git clone --filter=blob:none https://github.com/ninja-build/ninja.git --depth=1
cd ninja
cmake -Bbuild-cmake -DBUILD_TESTING=OFF -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" -DCMAKE_BUILD_TYPE=release -DCMAKE_CXX_COMPILER=/opt/gcc-indiff/bin/g++
cmake --build build-cmake
rm -f /usr/bin/ninja
cp build-cmake/ninja /usr/bin/ninja
cd ..
rm -rf ninja

/usr/bin/ninja --version



# install python 38
# yum -y install centos-release-scl
# yum -y install rh-python38 rh-python38-python-devel
# scl enable rh-python38 bash
# ln -s /opt/rh/rh-python38/root/usr/bin/python3 /usr/bin/python3
# ln -s /opt/rh/rh-python38/root/usr/bin/pip3 /usr/bin/pip3

yum -y remove python36 python36-pip python36-devel python3 python3-pip python3-devel
yum -y install yum-plugin-copr
yum -y copr enable adrienverge/python37
yum -y install python37 python37-devel python37-pip
python3 --version

yum -y install autoconf autoconf-archive icu wget automake libtool m4 pkgconfig

          
git --version

# 创建符号链接

# Verify installations

make -v
cmake --version || true
ninja --version || true

export PATH=/opt/gcc-indiff/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
git clone --filter=blob:none --depth 1 https://github.com/microsoft/vcpkg.git /opt/vcpkg
/opt/vcpkg/bootstrap-vcpkg.sh
export VCPKG_ROOT=/opt/vcpkg
export PATH=/opt/gcc-indiff/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib
export TRIPLET=x64-linux
# TRIPLET=x64-linux-dynamic

# 用 vcpkg 安装第三方库（确认需的端口名，必要时用 --overlay-ports)
# curl => 替代 libcurl-devel
# yum install libcurl-devel       # libcurl 开发库（HTTP 客户端、下载等功能）
# yum install zlib-devel          # zlib 开发库（通用压缩库）
# yum install lz4-devel           # LZ4 开发库（高速压缩，MySQL 用于快速压缩）
# yum install zstd                # Zstandard 压缩工具与库（快速压缩算法，现代替代选项）
# yum install snappy snappy-devel # Snappy 压缩库及开发文件（RocksDB 等依赖）
# yum install openssl openssl-devel   # OpenSSL 运行时与开发库（TLS/加密与 SSL 编译依赖）
# yum install pcre2-devel         # PCRE2 正则表达式开发库（正则匹配功能）
# yum install lzo-devel           # LZO 开发库（另一种压缩算法，部分组件可能依赖）
# yum install ncurses-devel       # ncurses 开发库（终端界面库，某些工具依赖）
# yum install libxml2-devel       # libxml2 开发库（XML 解析，部分插件或工具需要）
# yum install libaio-devel        # libaio 异步 IO 开发库（高性能 IO 支持，数据库常用）
# yum install libevent-devel      # libevent 开发库（高性能事件通知库，网络组件常用）
# yum install bzip2-devel         # bzip2 开发库（压缩算法支持）
# $VCPKG_ROOT/vcpkg install boost
# openssl

# 用 vcpkg 安装动态 curl （会生成 libcurl.so 并自动依赖 libssl/libcrypto)
# cyrus-sasl openldap  use bundle protobuf
# CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ \
#     LDFLAGS="-fuse-ld=mold -Wl,--strip-all -Wl,--gc-sections -L/opt/gcc-indiff/lib64 -L/opt/gcc-indiff/lib -Wl,-rpath,/opt/gcc-indiff/lib64 -Wl,-rpath,/opt/gcc-indiff/lib" \
#     CFLAGS="-I/opt/gcc-indiff/include" \
#     CXXFLAGS="-I/opt/gcc-indiff/include" \
#     $VCPKG_ROOT/vcpkg install jemalloc --triplet x64-linux-dynamic --clean-after-build || cat /opt/vcpkg/buildtrees/jemalloc/make-all-x64-linux-dynamic-dbg-err.log

cd /opt/
git clone https://github.com/facebook/jemalloc.git --depth 1
cd jemalloc
sed -i 's/std::__throw_bad_alloc()/throw std::bad_alloc()/g' src/jemalloc_cpp.cpp
sh autogen.sh
env CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ ./configure --prefix=/opt/fbjemalloc
make -j$(nproc)
make install

cd /opt/vcpkg/
CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ LDOPTS="-fuse-ld=mold -Wl,--strip-all -Wl,--gc-sections " $VCPKG_ROOT/vcpkg install numactl openssl curl[core,non-http,ssl,openssl,zstd] snappy krb5 lmdb --triplet x64-linux-dynamic --clean-after-build \
            || cat /workspace/vcpkg/installed/vcpkg/issue_body.md
CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ LDOPTS="-fuse-ld=mold -Wl,--strip-all -Wl,--gc-sections " $VCPKG_ROOT/vcpkg install \
            zlib \
            lz4 \
            zstd \
            bzip2 \
            lzo \
            libxml2 \
            libevent \
            pcre2 \
            ncurses \
            libaio  \
            --triplet $TRIPLET --clean-after-build	\
            || cat /workspace/vcpkg/installed/vcpkg/issue_body.md



cd /opt
# install icu  
wget https://github.com/unicode-org/icu/releases/download/release-68-2/icu4c-68_2-src.tgz
tar -xzf icu4c-68_2-src.tgz
cd icu/source
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:$LD_LIBRARY_PATH
./configure --prefix=/usr/local/icu68
make -j$(nproc)
make install

echo "CentOS 7 percona-build environment setup completed successfully!"
