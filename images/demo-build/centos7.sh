#!/bin/bash
# author: indiff
# CentOS 7 dependency installation and configuration script
set -xe
echo 'LANG=zh_CN.UTF-8' >> /etc/environment
echo 'LANGUAGE=zh_CN.UTF-8' >> /etc/environment
echo 'LC_ALL=zh_CN.UTF-8' >> /etc/environment
echo 'LC_CTYPE=zh_CN.UTF-8' >> /etc/environment
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
yum install -y perl-Test-Simple perl-FindBin perl-IPC-Cmd perl-Text-Template perl-File-Compare perl-File-Copy perl-Data-Dumper perl-Time-Piece
# 基础依赖
yum install -y zip unzip rsync ninja-build curl wget tar xz unzip bzip2 which rsync tree pkgconfig \
make cmake3 gcc gcc-c++ flex bison gettext \
autoconf automake libtool patchelf \
readline-devel \
perl-ExtUtils-Embed tree

# Install development tools and dependencies
yum install -y \
    tree \
    sed \
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
git clone --filter=blob:none https://github.com/ninja-build/ninja.git --depth=1
cd ninja
cmake -Bbuild-cmake -DBUILD_TESTING=OFF -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" -DCMAKE_BUILD_TYPE=release -DCMAKE_CXX_COMPILER=/opt/gcc-indiff/bin/g++
cmake --build build-cmake
rm -f /usr/bin/ninja
cp build-cmake/ninja /usr/bin/ninja
cd ..
rm -rf ninja

/usr/bin/ninja --version

yum -y remove python36 python36-pip python36-devel python3 python3-pip python3-devel
yum -y install yum-plugin-copr
yum -y copr enable adrienverge/python37
yum -y install python37 python37-devel python37-pip
python3 --version
          
git --version

make -v
cmake --version || true
ninja --version || true

export PATH=/opt/gcc-indiff/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/opt/gcc-indiff/lib64:/opt/gcc-indiff/lib

echo "CentOS 7 demo-build environment setup completed successfully!"
