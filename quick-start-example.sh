#!/bin/bash
# MySQL性能测试框架快速开始示例
# 这个脚本演示如何使用性能测试框架

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "=================================================="
echo "MySQL性能测试框架 - 快速开始示例"
echo "=================================================="  
echo -e "${NC}"

echo -e "${GREEN}本示例将演示如何使用MySQL性能测试框架${NC}"
echo ""

# 检查是否在正确的目录
if [[ ! -f "mysql-performance-test.sh" ]]; then
    echo "错误: 请在项目根目录运行此脚本"
    exit 1
fi

# 步骤1: 检查框架状态
echo -e "${YELLOW}步骤1: 检查测试框架状态${NC}"
echo "运行: ./performance-tests/test-framework.sh deps"
./performance-tests/test-framework.sh deps
echo ""

# 步骤2: 显示帮助信息
echo -e "${YELLOW}步骤2: 查看主脚本帮助信息${NC}"
echo "运行: ./mysql-performance-test.sh help"
./mysql-performance-test.sh help
echo ""

# 步骤3: 初始化环境
echo -e "${YELLOW}步骤3: 初始化测试环境${NC}"
echo "运行: ./mysql-performance-test.sh init"
./mysql-performance-test.sh init
echo ""

# 步骤4: 显示数据库管理功能
echo -e "${YELLOW}步骤4: 查看数据库管理功能${NC}"
echo "运行: ./performance-tests/database-manager.sh"
./performance-tests/database-manager.sh
echo ""

# 步骤5: 生成示例报告
echo -e "${YELLOW}步骤5: 查看示例测试报告${NC}"
echo "示例报告位置: demo-report.md"
echo "可以查看: cat demo-report.md | head -50"
echo ""
echo "示例报告预览:"
echo "=============="
head -30 demo-report.md
echo "..."
echo "(完整报告见 demo-report.md 文件)"
echo ""

# 步骤6: 显示下一步操作
echo -e "${YELLOW}下一步操作 (可选 - 需要较长时间):${NC}"
echo ""
echo "如果您想运行完整的性能测试，请执行:"
echo ""
echo -e "${GREEN}# 安装依赖 (需要root权限)${NC}"
echo "sudo ./install-dependencies.sh"
echo ""
echo -e "${GREEN}# 下载和安装MySQL数据库 (需要网络连接)${NC}"
echo "./mysql-performance-test.sh download"
echo "./mysql-performance-test.sh install"
echo ""
echo -e "${GREEN}# 运行完整性能测试 (需要几小时)${NC}"
echo "./mysql-performance-test.sh test"
echo ""
echo -e "${GREEN}# 生成测试报告${NC}"
echo "./mysql-performance-test.sh report"
echo ""

echo -e "${BLUE}=================================================="
echo "快速开始示例完成!"
echo "=================================================="
echo -e "${NC}"

echo "更多信息请查看:"
echo "- README-performance-test.md - 完整使用文档"
echo "- demo-report.md - 示例测试报告"
echo "- performance-tests/ - 测试脚本目录"
echo ""
echo "如有问题，请联系: indiff@126.com"