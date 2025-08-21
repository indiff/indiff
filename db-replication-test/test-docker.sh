#!/bin/bash

# Docker 环境下的主从同步测试脚本 
# 简化版本，用于快速测试和演示

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"

# 创建结果目录
mkdir -p "$RESULTS_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$RESULTS_DIR/docker-test.log"
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

# 显示帮助
show_help() {
    cat << EOF
Docker 环境主从同步测试

用法:
    $0 [选项]

选项:
    --quick-test        快速测试模式
    --full-test         完整测试模式
    --cleanup          清理 Docker 环境
    --help             显示帮助

测试场景:
    1. MariaDB 主库 (InnoDB) → MariaDB 从库 (InnoDB/ColumnStore)
    2. Percona 主库 (InnoDB) → Percona 从库 (InnoDB/RocksDB)

EOF
}

# 检查 Docker 环境
check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker 未安装"
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose 未安装"
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker 服务未运行"
    fi
    
    log "Docker 环境检查通过"
}

# 启动 Docker 服务
start_services() {
    log "启动 Docker 服务..."
    
    cd "$SCRIPT_DIR"
    docker-compose down -v 2>/dev/null || true
    docker-compose up -d
    
    # 等待服务健康检查通过
    log "等待服务启动..."
    local retries=60
    while [[ $retries -gt 0 ]]; do
        if docker-compose ps | grep -q "Up (healthy)"; then
            local healthy_count=$(docker-compose ps | grep -c "Up (healthy)" || echo "0")
            local total_services=$(docker-compose ps | grep -c "Up" || echo "0")
            
            if [[ $healthy_count -eq $total_services && $total_services -gt 0 ]]; then
                log "所有服务启动成功"
                return 0
            fi
        fi
        
        sleep 3
        retries=$((retries - 1))
    done
    
    log "服务启动状态："
    docker-compose ps
    error "服务启动超时"
}

# 配置主从复制
setup_replication() {
    local master_container="$1"
    local slave_container="$2"
    local scenario_name="$3"
    
    log "配置主从复制: $master_container -> $slave_container"
    
    # 在主库创建复制用户
    docker exec "$master_container" mysql -uroot -proot -e "
        CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'repl_password';
        GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
        FLUSH PRIVILEGES;
    "
    
    # 获取主库状态
    local master_status
    master_status=$(docker exec "$master_container" mysql -uroot -proot -e "SHOW MASTER STATUS\\G")
    local master_file=$(echo "$master_status" | grep "File:" | awk '{print $2}')
    local master_pos=$(echo "$master_status" | grep "Position:" | awk '{print $2}')
    
    if [[ -z "$master_file" || -z "$master_pos" ]]; then
        error "无法获取主库状态"
    fi
    
    log "主库状态: File=$master_file, Position=$master_pos"
    
    # 获取主库 IP
    local master_ip
    master_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$master_container")
    
    # 配置从库
    docker exec "$slave_container" mysql -uroot -proot -e "
        STOP SLAVE;
        CHANGE MASTER TO
            MASTER_HOST='$master_ip',
            MASTER_PORT=3306,
            MASTER_USER='repl',
            MASTER_PASSWORD='repl_password',
            MASTER_LOG_FILE='$master_file',
            MASTER_LOG_POS=$master_pos;
        START SLAVE;
    "
    
    # 检查从库状态
    sleep 5
    local slave_status
    slave_status=$(docker exec "$slave_container" mysql -uroot -proot -e "SHOW SLAVE STATUS\\G")
    
    if echo "$slave_status" | grep -q "Slave_IO_Running: Yes" && echo "$slave_status" | grep -q "Slave_SQL_Running: Yes"; then
        log "$scenario_name 主从复制配置成功"
        return 0
    else
        log "$scenario_name 主从复制配置失败"
        echo "$slave_status"
        return 1
    fi
}

# 运行同步测试
run_sync_test() {
    local master_container="$1"
    local slave_container="$2"
    local scenario_name="$3"
    local test_result_file="$4"
    
    log "开始 $scenario_name 同步测试..."
    
    local start_time=$(date +%s)
    local test_errors=0
    local total_tests=0
    
    # 创建测试数据库和表
    docker exec "$master_container" mysql -uroot -proot -e "
        CREATE DATABASE IF NOT EXISTS test_replication;
        USE test_replication;
        CREATE TABLE IF NOT EXISTS sync_test (
            id INT PRIMARY KEY AUTO_INCREMENT,
            data VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    "
    
    # 测试基本同步
    local delays=()
    for i in {1..10}; do
        local insert_time=$(date +%s.%N)
        
        docker exec "$master_container" mysql -uroot -proot -e "
            USE test_replication;
            INSERT INTO sync_test (data) VALUES ('test_data_$i');
        "
        
        # 等待同步并测量延迟
        local max_wait=10
        local wait_time=0
        while [[ $wait_time -lt $max_wait ]]; do
            local slave_count=$(docker exec "$slave_container" mysql -uroot -proot -se "
                USE test_replication;
                SELECT COUNT(*) FROM sync_test WHERE data='test_data_$i';
            " 2>/dev/null || echo "0")
            
            if [[ "$slave_count" -ge 1 ]]; then
                local sync_time=$(date +%s.%N)
                local delay=$(echo "$sync_time - $insert_time" | bc -l)
                delays+=("$delay")
                log "记录 $i 同步延迟: ${delay}s"
                break
            fi
            
            sleep 0.5
            wait_time=$(echo "$wait_time + 0.5" | bc -l)
        done
        
        total_tests=$((total_tests + 1))
        
        if [[ $wait_time -ge $max_wait ]]; then
            log "记录 $i 同步超时"
            test_errors=$((test_errors + 1))
        fi
    done
    
    # 最终一致性检查
    sleep 3
    local master_count=$(docker exec "$master_container" mysql -uroot -proot -se "USE test_replication; SELECT COUNT(*) FROM sync_test;")
    local slave_count=$(docker exec "$slave_container" mysql -uroot -proot -se "USE test_replication; SELECT COUNT(*) FROM sync_test;" 2>/dev/null || echo "0")
    
    local end_time=$(date +%s)
    local test_duration=$((end_time - start_time))
    
    # 计算平均延迟
    local avg_delay=0
    if [[ ${#delays[@]} -gt 0 ]]; then
        local sum_delay=0
        for delay in "${delays[@]}"; do
            sum_delay=$(echo "$sum_delay + $delay" | bc -l)
        done
        avg_delay=$(echo "scale=3; $sum_delay / ${#delays[@]}" | bc -l)
    fi
    
    local success_rate=$(echo "scale=2; ($total_tests - $test_errors) * 100 / $total_tests" | bc -l)
    local sync_success=$([ "$master_count" == "$slave_count" ] && echo "true" || echo "false")
    
    # 生成结果
    cat > "$test_result_file" << EOF
{
    "scenario": "$scenario_name",
    "master_container": "$master_container",
    "slave_container": "$slave_container",
    "test_duration": $test_duration,
    "total_tests": $total_tests,
    "errors": $test_errors,
    "success_rate": $success_rate,
    "average_delay": $avg_delay,
    "delays": [$(IFS=,; echo "${delays[*]}")],
    "final_master_count": $master_count,
    "final_slave_count": $slave_count,
    "sync_success": $sync_success,
    "timestamp": "$(date -Iseconds)"
}
EOF
    
    log "$scenario_name 测试完成: 成功率 $success_rate%, 平均延迟 ${avg_delay}s, 数据一致性 $sync_success"
    
    return $test_errors
}

# 快速测试模式
quick_test() {
    log "开始快速测试模式..."
    
    check_docker
    start_services
    
    local total_errors=0
    
    # 测试场景1: MariaDB 主从
    log "=== 场景1: MariaDB 主库 → MariaDB 从库 ==="
    if setup_replication "mariadb-master" "mariadb-slave" "MariaDB主从"; then
        local result_file="$RESULTS_DIR/quick_test_mariadb_$(date +%Y%m%d_%H%M%S).json"
        if ! run_sync_test "mariadb-master" "mariadb-slave" "MariaDB主从" "$result_file"; then
            total_errors=$((total_errors + 1))
        fi
    else
        total_errors=$((total_errors + 1))
    fi
    
    # 测试场景2: Percona 主从  
    log "=== 场景2: Percona 主库 → Percona 从库 ==="
    if setup_replication "percona-master" "percona-slave" "Percona主从"; then
        local result_file="$RESULTS_DIR/quick_test_percona_$(date +%Y%m%d_%H%M%S).json"
        if ! run_sync_test "percona-master" "percona-slave" "Percona主从" "$result_file"; then
            total_errors=$((total_errors + 1))
        fi
    else
        total_errors=$((total_errors + 1))
    fi
    
    # 生成汇总报告
    generate_quick_report
    
    if [[ $total_errors -eq 0 ]]; then
        log "快速测试完成，所有场景通过"
        return 0
    else
        log "快速测试完成，$total_errors 个场景失败"
        return 1
    fi
}

# 生成快速测试报告
generate_quick_report() {
    local report_file="$RESULTS_DIR/quick_test_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << 'EOF'
# 数据库主从同步快速测试报告

## 测试概述

本报告展示了使用 Docker 环境进行的数据库主从同步快速测试结果。

## 测试环境

- 运行环境: Docker
- 测试时间: $(date)
- 测试模式: 快速测试

## 测试结果

EOF
    
    # 添加测试结果
    for result_file in "$RESULTS_DIR"/quick_test_*.json; do
        if [[ -f "$result_file" ]]; then
            local scenario=$(jq -r '.scenario' "$result_file" 2>/dev/null || echo "未知")
            local success_rate=$(jq -r '.success_rate' "$result_file" 2>/dev/null || echo "0")
            local avg_delay=$(jq -r '.average_delay' "$result_file" 2>/dev/null || echo "0")
            local sync_success=$(jq -r '.sync_success' "$result_file" 2>/dev/null || echo "false")
            
            cat >> "$report_file" << EOF

### $scenario

- **同步成功**: $sync_success
- **成功率**: $success_rate%
- **平均延迟**: ${avg_delay}s

EOF
        fi
    done
    
    cat >> "$report_file" << 'EOF'

## 结论

快速测试主要验证了主从复制的基本功能和同步性能。

EOF
    
    log "快速测试报告已生成: $report_file"
}

# 清理环境
cleanup() {
    log "清理 Docker 环境..."
    
    cd "$SCRIPT_DIR"
    docker-compose down -v
    docker system prune -f
    
    log "清理完成"
}

# 主函数
main() {
    local mode="quick"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick-test)
                mode="quick"
                shift
                ;;
            --full-test)
                mode="full"
                shift
                ;;
            --cleanup)
                cleanup
                exit 0
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "未知参数: $1"
                ;;
        esac
    done
    
    case "$mode" in
        "quick")
            quick_test
            ;;
        "full")
            log "完整测试模式暂未实现，使用快速测试"
            quick_test
            ;;
        *)
            error "未知模式: $mode"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi