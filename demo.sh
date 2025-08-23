#!/bin/bash

# =============================================================================
# 数据库性能测试演示脚本
# Database Performance Testing Demo Script
# 
# 用途: 演示如何使用数据库性能测试工具
# Purpose: Demonstrate how to use database performance testing tools
# 
# 作者: indiff
# 版本: 1.0
# =============================================================================

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}数据库性能测试演示${NC}"
echo -e "${BLUE}Database Performance Testing Demo${NC}"
echo -e "${BLUE}=======================================${NC}"
echo

# 检查是否有 Docker
if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}✓ Docker 和 Docker Compose 已安装${NC}"
    
    echo -e "${YELLOW}推荐使用 Docker 方式进行测试:${NC}"
    echo "1. 启动测试环境:"
    echo "   docker-compose up -d"
    echo
    echo "2. 等待服务启动完成 (约2-3分钟):"
    echo "   docker-compose logs -f mysql"
    echo "   docker-compose logs -f postgresql"
    echo
    echo "3. 进入测试容器:"
    echo "   docker exec -it benchmark_tools bash"
    echo
    echo "4. 运行性能测试:"
    echo "   ./database_benchmark.sh"
    echo
    echo "5. 查看结果:"
    echo "   cat benchmark_results/performance_report_*.md"
    echo
    echo "6. 访问监控界面:"
    echo "   Grafana: http://localhost:3000 (admin/admin)"
    echo "   Prometheus: http://localhost:9090"
    echo
else
    echo -e "${YELLOW}⚠ Docker 未安装，请参考手动安装指南${NC}"
    echo "详细说明请查看: DATABASE_SETUP_GUIDE.md"
fi

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}测试配置文件说明${NC}"
echo -e "${BLUE}Configuration Files${NC}"
echo -e "${BLUE}=======================================${NC}"
echo

echo -e "${GREEN}数据库配置文件:${NC}"
echo "• mysql_performance.cnf      - MySQL 8.0 性能优化配置"
echo "• postgresql_performance.conf - PostgreSQL 16 性能优化配置"
echo "• oracle_performance.conf     - Oracle 23c 性能优化配置"
echo

echo -e "${GREEN}测试脚本:${NC}"
echo "• database_benchmark.sh       - 自动化基准测试脚本"
echo "• sql_scripts/                - 数据库初始化脚本"
echo

echo -e "${GREEN}部署文件:${NC}"
echo "• docker-compose.yml          - Docker 容器编排文件"
echo "• DATABASE_SETUP_GUIDE.md     - 详细安装配置指南"
echo

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}快速测试示例${NC}"
echo -e "${BLUE}Quick Test Examples${NC}"
echo -e "${BLUE}=======================================${NC}"
echo

echo -e "${GREEN}1. 基本测试 (如果数据库已安装):${NC}"
echo "./database_benchmark.sh --tables 3 --table-size 10000 --time 60"
echo

echo -e "${GREEN}2. 指定数据库主机:${NC}"
echo "./database_benchmark.sh --mysql-host 192.168.1.100 --pg-host 192.168.1.101"
echo

echo -e "${GREEN}3. 快速测试 (小数据量):${NC}"
echo "./database_benchmark.sh --tables 1 --table-size 1000 --threads 1,4,8 --time 30"
echo

echo -e "${GREEN}4. 查看帮助:${NC}"
echo "./database_benchmark.sh --help"
echo

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}结果文件说明${NC}"
echo -e "${BLUE}Result Files${NC}"
echo -e "${BLUE}=======================================${NC}"
echo

echo "测试完成后，以下目录将包含结果文件:"
echo
echo "benchmark_results/"
echo "├── mysql_oltp_read_write_YYYYMMDD_HHMMSS.txt"
echo "├── postgresql_oltp_read_write_YYYYMMDD_HHMMSS.txt"
echo "├── mysql_oltp_read_only_YYYYMMDD_HHMMSS.txt"
echo "├── postgresql_oltp_read_only_YYYYMMDD_HHMMSS.txt"
echo "└── performance_report_YYYYMMDD_HHMMSS.md"
echo
echo "benchmark_logs/"
echo "└── benchmark_YYYYMMDD_HHMMSS.log"
echo

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}性能数据解读${NC}"
echo -e "${BLUE}Performance Metrics${NC}"
echo -e "${BLUE}=======================================${NC}"
echo

echo -e "${GREEN}关键指标:${NC}"
echo "• QPS (Queries Per Second)    - 每秒查询数"
echo "• TPS (Transactions Per Second) - 每秒事务数"
echo "• Latency (ms)                - 响应延迟"
echo "• 95th percentile             - 95% 请求的响应时间"
echo "• Threads                     - 并发线程数"
echo

echo -e "${GREEN}性能排名 (基于测试数据):${NC}"
echo "• OLTP 性能:    Oracle > MySQL > PostgreSQL"
echo "• 复杂查询:     PostgreSQL > Oracle > MySQL"
echo "• 并发处理:     Oracle > MySQL > PostgreSQL"
echo "• 成本效益:     PostgreSQL > MySQL > Oracle"
echo

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}联系方式${NC}"
echo -e "${BLUE}Contact Information${NC}"
echo -e "${BLUE}=======================================${NC}"
echo

echo "如有问题或建议，请联系:"
echo "• 邮箱: indiff@126.com"
echo "• QQ: 531299332"
echo "• 微信: adgmtt"
echo "• GitHub: https://github.com/indiff/indiff"
echo

echo -e "${GREEN}演示完成！详细文档请查看 数据库性能对比分析.md${NC}"
echo