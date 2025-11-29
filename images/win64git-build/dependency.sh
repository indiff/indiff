#!/bin/bash
# SPDX-License-Identifier: GPL-3.0
# CentOS 7 dependency installation and configuration script
set -xe
echo 'LANG=zh_CN.UTF-8' >> /etc/environment
echo 'LANGUAGE=zh_CN.UTF-8' >> /etc/environment
echo 'LC_ALL=zh_CN.UTF-8' >> /etc/environment
echo 'LC_CTYPE=zh_CN.UTF-8' >> /etc/environment

# 在 Ubuntu/Debian 上
sudo apt-get update
# sudo apt-get install pkg-config-mingw-w64


sudo apt-get -y install pkg-config

# git clone --filter=blob:none https://github.com/ninja-build/ninja.git --depth=1
# cd ninja
# cmake -Bbuild-cmake -DBUILD_TESTING=OFF -DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" -DCMAKE_BUILD_TYPE=release 
# cmake --build build-cmake
# rm -f /usr/bin/ninja
# cp build-cmake/ninja /usr/bin/ninja
# cd ..
# rm -rf ninja

wget https://github.com/ninja-build/ninja/releases/download/v1.13.2/ninja-linux.zip
unzip ninja-linux.zip -d .
cp ninja /usr/bin/ninja
rm -f ninja-linux.zip
/usr/bin/ninja --version

git clone --filter=blob:none --depth 1 https://github.com/microsoft/vcpkg.git /opt/vcpkg
export VCPKG_ROOT=/opt/vcpkg
/opt/vcpkg/bootstrap-vcpkg.sh

$VCPKG_ROOT/vcpkg install \
            apr \
            --triplet x64-mingw-static --clean-after-build	|| cat $VCPKG_ROOT/installed/vcpkg/issue_body.md || true
$VCPKG_ROOT/vcpkg install \
            openssl curl[openssl] openssl zlib expat pcre2 --triplet x64-mingw-dynamic --clean-after-build || cat $VCPKG_ROOT/installed/vcpkg/issue_body.md 
# 查看配置输出日志
cat /opt/vcpkg/buildtrees/curl/config-x64-mingw-dynamic-out.log

# 查看错误日志
cat /opt/vcpkg/buildtrees/curl/config-x64-mingw-dynamic-rel-CMakeConfigureLog.yaml.log
cat /opt/vcpkg/buildtrees/curl/config-x64-mingw-dynamic-dbg-CMakeConfigureLog.yaml.log
            
echo "Win64 git-build environment setup completed successfully!"
