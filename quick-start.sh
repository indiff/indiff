#!/bin/bash

# Quick Start Script for MySQL vs Percona Performance Testing
# 快速启动 MySQL vs Percona 性能测试脚本

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查必要的依赖
check_dependencies() {
    log "检查系统依赖..."
    
    local missing_deps=()
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
            missing_deps+=("docker-compose")
        fi
    fi
    
    if ! command -v sysbench &> /dev/null; then
        missing_deps+=("sysbench")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "缺少以下依赖: ${missing_deps[*]}"
        log "请先安装缺少的依赖:"
        echo ""
        echo "Ubuntu/Debian:"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install -y docker.io docker-compose sysbench bc jq"
        echo ""
        echo "CentOS/RHEL:"
        echo "  sudo yum install -y docker docker-compose sysbench bc jq"
        echo ""
        exit 1
    fi
    
    log "依赖检查通过 ✓"
}

# 显示帮助信息
show_help() {
    cat << EOF
MySQL vs Percona 性能测试快速启动脚本

用法:
  $0 [选项]

选项:
  -h, --help          显示此帮助信息
  -q, --quick         快速测试 (1分钟, 小数据集)
  -s, --standard      标准测试 (5分钟, 中等数据集) [默认]
  -l, --long          长时间测试 (30分钟, 大数据集)
  -c, --compose       使用 Docker Compose 启动环境
  -m, --monitor       启动监控环境 (Prometheus + Grafana)
  --cleanup           清理所有测试容器和数据

示例:
  $0                  # 运行标准测试
  $0 -q               # 运行快速测试
  $0 -l               # 运行长时间测试
  $0 -c               # 使用 Docker Compose
  $0 -m               # 启动监控环境
  $0 --cleanup        # 清理环境

EOF
}

# 运行快速测试
run_quick_test() {
    log "运行快速性能测试 (1分钟)..."
    ./scripts/mysql-performance-test.sh \
        --test-duration 60 \
        --table-size 10000 \
        --threads "1 4 8"
}

# 运行标准测试
run_standard_test() {
    log "运行标准性能测试 (5分钟)..."
    ./scripts/mysql-performance-test.sh \
        --test-duration 300 \
        --table-size 100000 \
        --threads "1 4 8 16 32"
}

# 运行长时间测试
run_long_test() {
    log "运行长时间性能测试 (30分钟)..."
    ./scripts/mysql-performance-test.sh \
        --test-duration 1800 \
        --table-size 500000 \
        --threads "1 4 8 16 32 64 128"
}

# 使用 Docker Compose
use_docker_compose() {
    log "使用 Docker Compose 启动测试环境..."
    
    if [ -f "docker-compose.yml" ]; then
        log "启动数据库容器..."
        docker-compose up -d mysql percona
        
        log "等待数据库启动..."
        sleep 30
        
        log "在容器中运行测试..."
        docker-compose run --rm sysbench /scripts/mysql-performance-test.sh
        
        log "停止环境..."
        docker-compose down
    else
        log_error "未找到 docker-compose.yml 文件"
        exit 1
    fi
}

# 启动监控环境
start_monitoring() {
    log "启动监控环境 (Prometheus + Grafana)..."
    
    if [ -f "docker-compose.yml" ]; then
        docker-compose up -d prometheus grafana mysql-exporter percona-exporter mysql percona
        
        log "监控环境已启动:"
        log "  Grafana: http://localhost:3000 (admin/admin123)"
        log "  Prometheus: http://localhost:9090"
        log ""
        log "请等待数据库完全启动后再运行测试"
    else
        log_error "未找到 docker-compose.yml 文件"
        exit 1
    fi
}

# 清理环境
cleanup_environment() {
    log "清理测试环境..."
    
    # 停止所有相关容器
    docker stop $(docker ps -aq --filter name=mysql_perf_test) 2>/dev/null || true
    docker stop $(docker ps -aq --filter name=percona_performance_test) 2>/dev/null || true
    docker stop $(docker ps -aq --filter name=mysql_performance_test) 2>/dev/null || true
    
    # 删除容器
    docker rm $(docker ps -aq --filter name=mysql_perf_test) 2>/dev/null || true
    docker rm $(docker ps -aq --filter name=percona_performance_test) 2>/dev/null || true
    docker rm $(docker ps -aq --filter name=mysql_performance_test) 2>/dev/null || true
    
    # 使用 docker-compose 清理
    if [ -f "docker-compose.yml" ]; then
        docker-compose down -v 2>/dev/null || true
    fi
    
    # 清理悬空镜像
    docker system prune -f 2>/dev/null || true
    
    log "环境清理完成"
}

# 主函数
main() {
    # 检查是否在正确的目录
    if [ ! -f "scripts/mysql-performance-test.sh" ]; then
        log_error "请在项目根目录下运行此脚本"
        exit 1
    fi
    
    # 确保脚本可执行
    chmod +x scripts/mysql-performance-test.sh
    
    case "${1:-standard}" in
        quick|-q|--quick)
            check_dependencies
            run_quick_test
            ;;
        standard|-s|--standard|"")
            check_dependencies
            run_standard_test
            ;;
        long|-l|--long)
            check_dependencies
            run_long_test
            ;;
        compose|-c|--compose)
            check_dependencies
            use_docker_compose
            ;;
        monitor|-m|--monitor)
            check_dependencies
            start_monitoring
            ;;
        cleanup|--cleanup)
            cleanup_environment
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"