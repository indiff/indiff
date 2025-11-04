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


export WORK_DIR="$PWD"
export PREFIX="$WORK_DIR/gcc-${arch}"
export PATH="$PREFIX/bin:/usr/bin/core_perl:$PATH"
# export OPT_FLAGS="-flto -flto-compression-level=10 -O3 -pipe -ffunction-sections -fdata-sections"
export OPT_FLAGS="-flto-compression-level=10 -O2 -pipe -ffunction-sections -fdata-sections"

# update my gcc
curl -sLo /opt/gcc-indiff.zip ${{ env.gcc_indiff_centos7_url }}
unzip /opt/gcc-indiff.zip -d /opt/gcc-indiff
yum install -y zstd zstd-devel
# export LD_LIBRARY_PATH=$(find /usr -name libzstd.so.1):$LD_LIBRARY_PATH




SETUP_INSTALL_PREFIX="/opt/git"
# Require asciidoc and xmlto to build documents
if [[ -z "$SETUP_INSTALL_PREFIX" ]]; then
SETUP_INSTALL_PREFIX=/opt
fi

mkdir -p $SETUP_INSTALL_PREFIX/bin ;
mkdir -p $SETUP_INSTALL_PREFIX/git ;
cd $SETUP_INSTALL_PREFIX ;

export PATH="$SETUP_INSTALL_PREFIX/bin:$PATH"
if [[ ! -e "re2c-${{ env.RE2C_VERSION }}.tar.xz" ]]; then
wget https://github.com/skvadrik/re2c/releases/download/${{ env.RE2C_VERSION }}/re2c-${{ env.RE2C_VERSION }}.tar.xz;
if [[ $? -ne 0 ]]; then
    rm -f re2c-${{ env.RE2C_VERSION }}.tar.xz;
fi
fi
tar -axvf re2c-${{ env.RE2C_VERSION }}.tar.xz ;
cd re2c-${{ env.RE2C_VERSION }} ;
./configure --prefix=$SETUP_INSTALL_PREFIX/re2c/${{ env.RE2C_VERSION }} --with-pic=yes;
make CC=/opt/gcc-indiff/bin/gcc -j$(nproc) ;
make install;

if [[ -e "$SETUP_INSTALL_PREFIX/re2c/${{ env.RE2C_VERSION }}/bin" ]]; then
for UPDATE_LNK in $SETUP_INSTALL_PREFIX/re2c/${{ env.RE2C_VERSION }}/bin/*; do
    UNDATE_LNK_BASENAME="$(basename "$UPDATE_LNK")";
    if [ -e "$SETUP_INSTALL_PREFIX/bin/$UNDATE_LNK_BASENAME" ]; then
        rm -rf "$SETUP_INSTALL_PREFIX/bin/$UNDATE_LNK_BASENAME";
    fi
    ln -rsf "$UPDATE_LNK" "$SETUP_INSTALL_PREFIX/bin/$UNDATE_LNK_BASENAME" ;
done
fi

cd ..;



git clone https://github.com/Microsoft/vcpkg.git --depth 1 /opt/vcpkg
cd /opt/vcpkg
export VCPKG_ROOT=$(pwd)
export PATH=$VCPKG_ROOT:$PATH
./bootstrap-vcpkg.sh
./vcpkg integrate install
./vcpkg install curl[openssl] openssl zlib expat pcre2 --triplet x64-linux-dynamic

cd $SETUP_INSTALL_PREFIX
# -z "${{ github.event.inputs.build_ver }}" || 
# git 代码仓库直接在 centos7 编译， 会出现不兼容 glibc 问题,所以默认不使用 git 代码仓库编译
if [[ "${{ github.event.inputs.build_ver }}" == "nightly" ]]; then
git clone --depth 1 https://github.com/git/git.git
cd git
make configure
else
if [[ ! -e "git-${{ env.GIT_VERSION }}.tar.xz" ]]; then
wget https://mirrors.edge.kernel.org/pub/software/scm/git/git-${{ env.GIT_VERSION }}.tar.xz ;
if [[ $? -ne 0 ]]; then
    rm -f git-${{ env.GIT_VERSION }}.tar.xz;
fi
fi
tar -axvf git-${{ env.GIT_VERSION }}.tar.xz ;
cd git-${{ env.GIT_VERSION }};
fi

# -L${VCPKG_ROOT}/installed/x64-linux/include/lib
GIT_INSTALL_DIR=$SETUP_INSTALL_PREFIX/git/${{ needs.before_build.outputs.GIT_DEF_VER }}
mkdir -p $GIT_INSTALL_DIR/lib
mkdir -p $GIT_INSTALL_DIR/lib64
mkdir -p $GIT_INSTALL_DIR/include
cp -v $VCPKG_ROOT/installed/x64-linux-dynamic/lib/*.so* $GIT_INSTALL_DIR/lib/ || true
cp -v $VCPKG_ROOT/installed/x64-linux-dynamic/lib/*.so* $GIT_INSTALL_DIR/lib64/ || true
cp -v $VCPKG_ROOT/installed/x64-linux-dynamic/lib/*.a* $GIT_INSTALL_DIR/lib/ || true
cp -v $VCPKG_ROOT/installed/x64-linux-dynamic/lib/*.a* $GIT_INSTALL_DIR/lib64/ || true
cp -rv $VCPKG_ROOT/installed/x64-linux-dynamic/include/* $GIT_INSTALL_DIR/include/ || true

./configure --prefix=$GIT_INSTALL_DIR \
CFLAGS="-Os -s -m64 -flto -flto-compression-level=9 -ffunction-sections -fdata-sections -pipe -w -fPIC" \
LDFLAGS="-flto -flto-compression-level=9 -Wl,--gc-sections -Wl,-O2 -Wl,--compress-debug-sections=zlib -Wl,-rpath=\$\$ORIGIN/../../lib64:\$\$ORIGIN/../../lib" \
--with-curl=$GIT_INSTALL_DIR --with-openssl=$GIT_INSTALL_DIR --with-libpcre2=$GIT_INSTALL_DIR \
--with-zlib=$GIT_INSTALL_DIR --with-expat=$GIT_INSTALL_DIR --with-editor=vim  || cat config.log ;
# NO_GETTEXT=1  Set NO_GETTEXT to disable localization support and make Git only
# NO_GITWEB=1 
make CC=/opt/gcc-indiff/bin/gcc NO_TCLTK=1 NO_PERL=1 \
NO_SVN_TESTS=1 NO_IPV6=1 \
NO_PYTHON=1 NO_TEST=1 \
-j$(nproc) all ;
make install

if [[ -e "$SETUP_INSTALL_PREFIX/git/${{ needs.before_build.outputs.GIT_DEF_VER }}/bin" ]]; then
for UPDATE_LNK in $SETUP_INSTALL_PREFIX/git/${{ needs.before_build.outputs.GIT_DEF_VER }}/bin/*; do
    UNDATE_LNK_BASENAME="$(basename "$UPDATE_LNK")";
    if [ -e "$SETUP_INSTALL_PREFIX/bin/$UNDATE_LNK_BASENAME" ]; then
        rm -rf "$SETUP_INSTALL_PREFIX/bin/$UNDATE_LNK_BASENAME";
    fi
    ln -rsf "$UPDATE_LNK" "$SETUP_INSTALL_PREFIX/bin/$UNDATE_LNK_BASENAME" ;
done
fi
cd ../../../ ;
mkdir -p git-lfs;
cd git-lfs;

# git lfs
if [[ ! -e "git-lfs-linux-amd64-v${{ env.GIT_LFS_VERSION }}.tar.gz" ]]; then
wget https://github.com/git-lfs/git-lfs/releases/download/v${{ env.GIT_LFS_VERSION }}/git-lfs-linux-amd64-v${{ env.GIT_LFS_VERSION }}.tar.gz ;
if [[ $? -ne 0 ]]; then
    rm -f git-lfs-linux-amd64-v${{ env.GIT_LFS_VERSION }}.tar.gz;
fi
fi

mkdir git-lfs-v${{ env.GIT_LFS_VERSION }};
cd git-lfs-v${{ env.GIT_LFS_VERSION }} ; 
tar -axvf ../git-lfs-linux-amd64-v${{ env.GIT_LFS_VERSION }}.tar.gz ;
ls -lh
chmod +x ./git-lfs-${{ env.GIT_LFS_VERSION }}/install.sh
mkdir -p $SETUP_INSTALL_PREFIX/git-lfs/v${{ env.GIT_LFS_VERSION }}
env CC=/opt/gcc-indiff/bin/gcc PREFIX=$SETUP_INSTALL_PREFIX/git-lfs/v${{ env.GIT_LFS_VERSION }} ./git-lfs-${{ env.GIT_LFS_VERSION }}/install.sh ;

if [[ -e "$SETUP_INSTALL_PREFIX/git-lfs/v${{ env.GIT_LFS_VERSION }}/bin" ]]; then
for UPDATE_LNK in $SETUP_INSTALL_PREFIX/git-lfs/v${{ env.GIT_LFS_VERSION }}/bin/*; do
    UNDATE_LNK_BASENAME="$(basename "$UPDATE_LNK")";
    if [ -e "$SETUP_INSTALL_PREFIX/bin/$UNDATE_LNK_BASENAME" ]; then
        rm -rf "$SETUP_INSTALL_PREFIX/bin/$UNDATE_LNK_BASENAME";
    fi
    ln -rsf "$UPDATE_LNK" "$SETUP_INSTALL_PREFIX/bin/$UNDATE_LNK_BASENAME" ;
done
fi

cd ../../ ;

cd $SETUP_INSTALL_PREFIX
rm -f *.tar.xz
rm -rf vcpkg
rm -rf re2c-*
rm -rf git-*
/opt/gcc-indiff/bin/gcc -v > gcc.txt 2>&1
echo '#/bin/bash
GIT_INDIFF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="$HOME/.bashrc"
KEYWORD="git-indiff-core"
LINE="export PATH=\"/usr/local/git-indiff-core:\$PATH\" "

rm -f /usr/bin/git
rm -rf /usr/local/git-indiff-core
ln -sf "$GIT_INDIFF_DIR/bin/git" /usr/bin/git
ln -sf "$GIT_INDIFF_DIR/git/${{ needs.before_build.outputs.GIT_DEF_VER }}/libexec/git-core" /usr/local/git-indiff-core

# 如果包含关键字则删除
if grep -q "$KEYWORD" "$PROFILE"; then
sed -i "/$KEYWORD/d" "$PROFILE"
echo "已删除 $KEYWORD 相关行。"
echo "$LINE" >> "$PROFILE"
else
echo "$LINE" >> "$PROFILE"
echo "已追加 $KEYWORD 到 $PROFILE。"
fi


source ~/.bash_profile
echo "执行成功, 请执行 source ~/.bash_profile! 测试  git clone https://gitee.com/qwop/test_git.git" 
' > load_git.sh

zname=/workspace/git-indiff-centos7-${{ env.GIT_VERSION }}-x86_64-$(date +'%Y%m%d_%H%M')
zip -r -q -9 $zname.zip .
mv $zname.zip $zname.xz
# ls -lh *.xz

tree $SETUP_INSTALL_PREFIX

# free memory
free -h
sync
echo 3 > /proc/sys/vm/drop_caches
free -h && df -h

# get glibc Version
echo $(cut -d- -f2 <<<$(rpm -q glibc)) >> /workspace/glibc_version.txt
