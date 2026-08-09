#!/usr/bin/env bash
# set -euo pipefail
set -ex

echo $VCPKG_ROOT



rm -rf /opt/gcc-indiff /opt/gcc-indiff.zip
curl -sLo /opt/gcc-indiff.zip https://github.com/qwop/gcc-build/releases/download/20251222_2144_16.0.0/gcc-indiff-centos7-16.0.0-x86_64-20251222_2009.xz
unzip /opt/gcc-indiff.zip -d /opt/gcc-indiff

cd $VCPKG_ROOT

zip -r -q -9 /workspace/mysql-centos7-x86_64-demo-$(date +'%Y%m%d_%H%M').xz .