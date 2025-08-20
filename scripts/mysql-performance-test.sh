#!/bin/bash

# MySQL vs Percona Performance Testing Script
# 对比原版MySQL和Percona，进行并发测试并生成详细报告

set -e

# 配置变量
MYSQL_VERSION=${MYSQL_VERSION:-"8.0"}
PERCONA_VERSION=${PERCONA_VERSION:-"8.0"}
TEST_DATABASE=${TEST_DATABASE:-"performance_test"}
TEST_DURATION=${TEST_DURATION:-300}  # 5分钟测试
THREADS_LIST=${THREADS_LIST:-"1 4 8 16 32 64"}
TABLE_SIZE=${TABLE_SIZE:-100000}
REPORT_DIR=${REPORT_DIR:-"$(pwd)/performance_reports"}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# 检查依赖
check_dependencies() {
    log "检查必要的依赖..."
    
    local deps=("docker" "sysbench" "jq")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "缺少以下依赖: ${missing_deps[*]}"
        log "请安装缺少的依赖后重新运行"
        exit 1
    fi
    
    log "依赖检查通过"
}

# 创建报告目录
setup_report_dir() {
    log "设置报告目录: $REPORT_DIR"
    mkdir -p "$REPORT_DIR"
    
    # 创建时间戳目录
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    CURRENT_REPORT_DIR="$REPORT_DIR/test_$TIMESTAMP"
    mkdir -p "$CURRENT_REPORT_DIR"
    
    log "报告将保存到: $CURRENT_REPORT_DIR"
}

# 启动MySQL容器
start_mysql_container() {
    local db_type=$1
    local container_name="mysql_perf_test_${db_type}"
    local port=$2
    local image=$3
    
    log "启动 $db_type 容器: $container_name"
    
    # 停止并删除已存在的容器
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true
    
    # 启动新容器
    docker run -d \
        --name "$container_name" \
        -p "$port:3306" \
        -e MYSQL_ROOT_PASSWORD=test123 \
        -e MYSQL_DATABASE="$TEST_DATABASE" \
        -e MYSQL_USER=testuser \
        -e MYSQL_PASSWORD=testpass \
        --tmpfs /var/lib/mysql:rw,noexec,nosuid,size=2g \
        "$image"
    
    # 等待数据库启动
    log "等待 $db_type 数据库启动..."
    local retry_count=0
    local max_retries=60
    
    while [ $retry_count -lt $max_retries ]; do
        if docker exec "$container_name" mysqladmin ping -h localhost -u root -ptest123 &>/dev/null; then
            log "$db_type 数据库已启动"
            break
        fi
        sleep 2
        ((retry_count++))
    done
    
    if [ $retry_count -eq $max_retries ]; then
        log_error "$db_type 数据库启动超时"
        return 1
    fi
    
    # 创建测试用户和数据库
    docker exec "$container_name" mysql -u root -ptest123 -e "
        CREATE DATABASE IF NOT EXISTS $TEST_DATABASE;
        CREATE USER IF NOT EXISTS 'testuser'@'%' IDENTIFIED BY 'testpass';
        GRANT ALL PRIVILEGES ON $TEST_DATABASE.* TO 'testuser'@'%';
        FLUSH PRIVILEGES;
    "
    
    log "$db_type 容器启动成功"
}

# 准备测试数据
prepare_test_data() {
    local db_type=$1
    local port=$2
    
    log "为 $db_type 准备测试数据..."
    
    sysbench oltp_read_write \
        --mysql-host=127.0.0.1 \
        --mysql-port="$port" \
        --mysql-user=testuser \
        --mysql-password=testpass \
        --mysql-db="$TEST_DATABASE" \
        --tables=10 \
        --table-size="$TABLE_SIZE" \
        prepare
    
    log "$db_type 测试数据准备完成"
}

# 运行性能测试
run_performance_test() {
    local db_type=$1
    local port=$2
    local threads=$3
    local test_type=$4
    
    log "运行 $db_type 性能测试: $test_type (线程数: $threads)"
    
    local output_file="$CURRENT_REPORT_DIR/${db_type}_${test_type}_threads_${threads}.json"
    
    sysbench "$test_type" \
        --mysql-host=127.0.0.1 \
        --mysql-port="$port" \
        --mysql-user=testuser \
        --mysql-password=testpass \
        --mysql-db="$TEST_DATABASE" \
        --tables=10 \
        --table-size="$TABLE_SIZE" \
        --threads="$threads" \
        --time="$TEST_DURATION" \
        --report-interval=10 \
        --db-ps-mode=disable \
        --forced-shutdown=1 \
        run > "$output_file"
    
    log "$db_type $test_type 测试完成 (线程数: $threads)"
}

# 获取系统信息
collect_system_info() {
    local db_type=$1
    local container_name="mysql_perf_test_${db_type}"
    
    log "收集 $db_type 系统信息..."
    
    # 容器资源使用情况
    docker stats "$container_name" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" > "$CURRENT_REPORT_DIR/${db_type}_container_stats.txt"
    
    # MySQL状态信息
    docker exec "$container_name" mysql -u root -ptest123 -e "SHOW ENGINE INNODB STATUS\G" > "$CURRENT_REPORT_DIR/${db_type}_innodb_status.txt"
    docker exec "$container_name" mysql -u root -ptest123 -e "SHOW GLOBAL STATUS" > "$CURRENT_REPORT_DIR/${db_type}_global_status.txt"
    docker exec "$container_name" mysql -u root -ptest123 -e "SHOW GLOBAL VARIABLES" > "$CURRENT_REPORT_DIR/${db_type}_global_variables.txt"
    
    log "$db_type 系统信息收集完成"
}

# 清理测试数据
cleanup_test_data() {
    local db_type=$1
    local port=$2
    
    log "清理 $db_type 测试数据..."
    
    sysbench oltp_read_write \
        --mysql-host=127.0.0.1 \
        --mysql-port="$port" \
        --mysql-user=testuser \
        --mysql-password=testpass \
        --mysql-db="$TEST_DATABASE" \
        --tables=10 \
        cleanup
    
    log "$db_type 测试数据清理完成"
}

# 停止容器
stop_container() {
    local db_type=$1
    local container_name="mysql_perf_test_${db_type}"
    
    log "停止 $db_type 容器..."
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true
    log "$db_type 容器已停止"
}

# 生成测试报告
generate_report() {
    log "生成性能测试报告..."
    
    local report_file="$CURRENT_REPORT_DIR/performance_comparison_report.md"
    
    cat > "$report_file" << EOF
# MySQL vs Percona 性能测试报告

测试时间: $(date '+%Y-%m-%d %H:%M:%S')
测试持续时间: ${TEST_DURATION}秒
表大小: ${TABLE_SIZE}行
线程数: ${THREADS_LIST}

## 测试环境

- MySQL 版本: ${MYSQL_VERSION}
- Percona 版本: ${PERCONA_VERSION}
- 测试工具: sysbench
- 操作系统: $(uname -a)

## 测试场景

1. **OLTP 读写混合测试** (oltp_read_write)
2. **只读测试** (oltp_read_only)  
3. **只写测试** (oltp_write_only)
4. **插入测试** (oltp_insert)

EOF

    # 分析测试结果并添加到报告
    for test_type in "oltp_read_write" "oltp_read_only" "oltp_write_only" "oltp_insert"; do
        echo "## $test_type 测试结果" >> "$report_file"
        echo "" >> "$report_file"
        echo "| 线程数 | MySQL TPS | Percona TPS | 性能提升 | MySQL 延迟(ms) | Percona 延迟(ms) |" >> "$report_file"
        echo "|--------|-----------|-------------|----------|----------------|------------------|" >> "$report_file"
        
        for threads in $THREADS_LIST; do
            local mysql_file="$CURRENT_REPORT_DIR/mysql_${test_type}_threads_${threads}.json"
            local percona_file="$CURRENT_REPORT_DIR/percona_${test_type}_threads_${threads}.json"
            
            if [[ -f "$mysql_file" && -f "$percona_file" ]]; then
                local mysql_tps=$(grep "transactions:" "$mysql_file" | grep -oE '[0-9]+\.[0-9]+' | head -1)
                local percona_tps=$(grep "transactions:" "$percona_file" | grep -oE '[0-9]+\.[0-9]+' | head -1)
                local mysql_latency=$(grep "avg:" "$mysql_file" | grep -oE '[0-9]+\.[0-9]+' | head -1)
                local percona_latency=$(grep "avg:" "$percona_file" | grep -oE '[0-9]+\.[0-9]+' | head -1)
                
                if [[ -n "$mysql_tps" && -n "$percona_tps" ]]; then
                    local improvement=$(echo "scale=2; ($percona_tps - $mysql_tps) / $mysql_tps * 100" | bc -l 2>/dev/null || echo "N/A")
                    echo "| $threads | $mysql_tps | $percona_tps | ${improvement}% | $mysql_latency | $percona_latency |" >> "$report_file"
                fi
            fi
        done
        echo "" >> "$report_file"
    done
    
    cat >> "$report_file" << EOF

## 总结

- Percona Server 基于 MySQL 社区版，包含额外的性能优化和功能
- RocksDB 存储引擎在写密集型工作负载中可能表现更好
- 具体性能差异取决于工作负载类型和硬件配置

## 详细数据

所有详细的测试数据和系统信息保存在同一目录下的其他文件中。

EOF

    log "性能测试报告已生成: $report_file"
}

# 主函数
main() {
    log "开始 MySQL vs Percona 性能测试"
    
    check_dependencies
    setup_report_dir
    
    # 测试场景列表
    local test_types=("oltp_read_write" "oltp_read_only" "oltp_write_only" "oltp_insert")
    
    # 启动MySQL容器
    start_mysql_container "mysql" 3306 "mysql:${MYSQL_VERSION}"
    
    # 启动Percona容器  
    start_mysql_container "percona" 3307 "percona/percona-server:${PERCONA_VERSION}"
    
    # 为每个数据库运行测试
    for db_type in "mysql" "percona"; do
        local port
        if [[ "$db_type" == "mysql" ]]; then
            port=3306
        else
            port=3307
        fi
        
        log "开始测试 $db_type..."
        
        for test_type in "${test_types[@]}"; do
            log "准备 $test_type 测试..."
            prepare_test_data "$db_type" "$port"
            
            for threads in $THREADS_LIST; do
                run_performance_test "$db_type" "$port" "$threads" "$test_type"
                sleep 5  # 短暂休息
            done
            
            cleanup_test_data "$db_type" "$port"
        done
        
        collect_system_info "$db_type"
    done
    
    # 停止容器
    stop_container "mysql"
    stop_container "percona"
    
    # 生成报告
    generate_report
    
    log "性能测试完成！报告保存在: $CURRENT_REPORT_DIR"
}

# 帮助信息
show_help() {
    cat << EOF
MySQL vs Percona 性能测试脚本

用法: $0 [选项]

选项:
  -h, --help              显示此帮助信息
  --mysql-version         MySQL版本 (默认: 8.0)
  --percona-version       Percona版本 (默认: 8.0)
  --test-duration         测试持续时间(秒) (默认: 300)
  --table-size            测试表大小 (默认: 100000)
  --threads               线程数列表 (默认: "1 4 8 16 32 64")
  --report-dir            报告目录 (默认: ./performance_reports)

示例:
  $0
  $0 --test-duration 600 --table-size 200000
  $0 --threads "1 8 32" --mysql-version 8.0.30

EOF
}

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --mysql-version)
            MYSQL_VERSION="$2"
            shift 2
            ;;
        --percona-version)
            PERCONA_VERSION="$2"
            shift 2
            ;;
        --test-duration)
            TEST_DURATION="$2"
            shift 2
            ;;
        --table-size)
            TABLE_SIZE="$2"
            shift 2
            ;;
        --threads)
            THREADS_LIST="$2"
            shift 2
            ;;
        --report-dir)
            REPORT_DIR="$2"
            shift 2
            ;;
        *)
            log_error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 运行主函数
main