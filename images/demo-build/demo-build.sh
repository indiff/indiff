#!/usr/bin/env bash
set -euo pipefail

echo $VCPKG_ROOT

curl -#Lo lld-indiff.zip "https://github.com/indiff/gcc-build/releases/download/20251107_1309_16.0.0/lld-indiff-centos7-x86_64-20251107_1308.xz"
ls

unzip ldd-indiff.zip -d /opt/gcc-indiff
# 工具链前缀目录
TOOLCHAIN=/opt/gcc-indiff/bin
export PATH="$TOOLCHAIN:$PATH"

# 统一编译/链接参数
export CFLAGS="-O2 -g -pipe -fuse-ld=lld -Wall"
export CXXFLAGS="-O2 -g -pipe -fuse-ld=lld -Wall -std=c++17"
export LDFLAGS="-Wl,-Map=output.map -Wl,--gc-sections"

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