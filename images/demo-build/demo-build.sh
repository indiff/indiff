#!/usr/bin/env bash
# set -euo pipefail
set -ex

echo $VCPKG_ROOT

# curl -sLo lld-indiff.zip https://github.com/indiff/gcc-build/releases/download/20251107_1309_16.0.0/lld-indiff-centos7-x86_64-20251107_1308.xz
# ls
# unzip lld-indiff.zip -d /opt/gcc-indiff
# 工具链前缀目录
TOOLCHAIN=/opt/gcc-indiff/bin
export PATH="$TOOLCHAIN:$PATH"

# 统一编译/链接参数
export CFLAGS="-O2 -g -pipe -fuse-ld=lld -Wall"
export CXXFLAGS="-O2 -g -pipe -fuse-ld=lld -Wall -std=c++17"
export LDFLAGS="-Wl,-Map=output.map -Wl,--gc-sections"


TRIPLET=x64-linux
DEPS_SRC="$VCPKG_ROOT/installed/$TRIPLET"
DEPS_DST="/opt/fuck"
mkdir -p "$DEPS_DST"/{include,lib,lib64}


rm -rf /opt/gcc-indiff /opt/gcc-indiff.zip
curl -sLo /opt/gcc-indiff.zip https://github.com/qwop/gcc-build/releases/download/20251222_2144_16.0.0/gcc-indiff-centos7-16.0.0-x86_64-20251222_2009.xz
unzip /opt/gcc-indiff.zip -d /opt/gcc-indiff
