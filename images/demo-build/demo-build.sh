#!/usr/bin/env bash
set -euo pipefail

echo $VCPKG_ROOT

curl -sLo lld-indiff.zip https://github.com/indiff/gcc-build/releases/download/20251107_1309_16.0.0/lld-indiff-centos7-x86_64-20251107_1308.xz
ls
unzip lld-indiff.zip -d /opt/gcc-indiff
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


DEPS_SRC="$VCPKG_ROOT/installed/x64-linux"
# sync icu68
# rsync -a "/usr/local/icu68/include/" "$DEPS_DST/include/"
# rsync -a "/usr/local/icu68/lib/"    "$DEPS_DST/lib64/"    || true

rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a --copy-links "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true
# rsync -a --copy-links "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true
# rsync -a --copy-links "$DEPS_SRC/tools/protobuf/"    "$DEPS_DST/tools/"    || true

rsync -a "/opt/gcc-indiff/include/" "$DEPS_DST/include/"
rsync -a --copy-links "/opt/gcc-indiff/lib64/"    "$DEPS_DST/lib64/"    || true

DEPS_SRC="$VCPKG_ROOT/installed/x64-linux-dynamic"

# 2) 复制头文件与动态库（.so 与 .so.*）及 pkgconfig
rsync -a "$DEPS_SRC/include/" "$DEPS_DST/include/"
rsync -a "$DEPS_SRC/lib/"      "$DEPS_DST/lib/"      || true
# rsync -a "$DEPS_SRC/lib64/"    "$DEPS_DST/lib64/"    || true
        
rsync -a "/opt/gcc-indiff/include/" "$DEPS_DST/include/"
rsync -a "/opt/gcc-indiff/lib64/"    "$DEPS_DST/lib64/"    || true

# 如果宿主镜像/系统有 /lib64/libjemalloc.so.1 同步到目标目录
if [ -f /lib64/libjemalloc.so.1 ]; then
     echo "Found /lib64/libjemalloc.so.1 on build host, copying to $DEPS_DST/lib64"
     mkdir -p "$DEPS_DST/lib64"
     cp -a /lib64/libjemalloc.so* "$DEPS_DST/lib64/" || true
     chmod 644 "$DEPS_DST/lib64"/libjemalloc.so* 2>/dev/null || true
fi

for d in lib lib64; do
[[ -d "$DEPS_DST/$d/pkgconfig" ]] || mkdir -p "$DEPS_DST/$d/pkgconfig"
rsync -a "$DEPS_SRC/$d/pkgconfig/" "$DEPS_DST/$d/pkgconfig/" 2>/dev/null || true
done



git clone --filter=blob:none --depth 1 https://github.com/cyrusimap/cyrus-sasl.git
cd cyrus-sasl
# sh autogen.sh

export CFLAGS="-Wall "
./autogen.sh --prefix="$DEPS_DST" \
    --with-openssl="$DEPS_DST"
    # --with-staticsasl
env LDFLAGS="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++  \
make install DESTDIR="$DEPS_DST" || true
# make -j$(nproc)
# make install

cd ..
git clone --filter=blob:none --depth 1 https://git.openldap.org/openldap/openldap.git
cd openldap
env CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++ ./configure --prefix=$DEPS_DST --with-cyrus-sasl="$DEPS_DST" --with-tls="openssl"
env LDFLAGS="/opt/gcc-indiff/lib64:$DEPS_DST/lib:$DEPS_DST/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" CC=/opt/gcc-indiff/bin/gcc CXX=/opt/gcc-indiff/bin/g++  \
make install DESTDIR="$DEPS_DST" || true


echo "[INFO] 使用 gcc 路径: $(command -v gcc)"
echo "[INFO] 使用 g++ 路径: $(command -v g++)"
echo "[INFO] 预期链接器: $TOOLCHAIN/ld.lld"

# 生成简单源代码
cat > test.c <<'EOF'
#include <stdio.h>
int main(void) {
    printf("Hello C\n");
    return 0;
}
EOF

cat > test.cpp <<'EOF'
#include <iostream>
int main() {
    std::cout << "Hello C++\n";
    return 0;
}
EOF

# 编译并输出详细过程，抓取链接器调用行
echo "[INFO] 编译 C (gcc)..."
gcc $CFLAGS $LDFLAGS -v test.c -o test_c 2> build_c.log
grep -E "collect2|ld.lld" build_c.log || true

echo "[INFO] 编译 C++ (g++)..."
g++ $CXXFLAGS $LDFLAGS -v test.cpp -o test_cpp 2> build_cpp.log
grep -E "collect2|ld.lld" build_cpp.log || true

# 使用 -### 精简展示真正执行的命令
echo "[INFO] gcc -### 链接阶段指令:"
gcc $CFLAGS $LDFLAGS -### test.c -o test_c_dummy 2> gcc_cmd.log
grep ld.lld gcc_cmd.log || cat gcc_cmd.log

echo "[INFO] g++ -### 链接阶段指令:"
g++ $CXXFLAGS $LDFLAGS -### test.cpp -o test_cpp_dummy 2> gpp_cmd.log
grep ld.lld gpp_cmd.log || cat gpp_cmd.log

# 运行测试程序
echo "[INFO] 运行结果:"
./test_c
./test_cpp

# 显示生成的链接 map 文件（截取前 20 行）
echo "[INFO] 链接映射文件片段:"
head -n 20 output.map || true

echo "[DONE] 若日志中出现 ld.lld 即证明使用 LLD 作为链接器。"
