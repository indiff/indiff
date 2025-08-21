#!/bin/bash

# 数据库主从同步测试脚本
# 测试 Percona Server 8.0 与 MariaDB 之间的主从同步

set -euo pipefail

# 全局配置
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
PERCONA_URL="https://github.com/indiff/indiff/releases/download/20250821_0401_percona80/percona80-centos7-x86_64-20250821_0358.xz"
PERCONA_PORT=3306
MARIADB_PORT=3307
TEST_DB="test_replication"

# 创建结果目录
mkdir -p "$RESULTS_DIR"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$RESULTS_DIR/test.log"
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

# 显示使用帮助
show_help() {
    cat << EOF
数据库主从同步测试工具

用法:
    $0 [选项]

选项:
    --scenario=N        只运行指定场景 (1 或 2)
    --detailed-report   生成详细报告
    --cleanup          清理测试环境
    --help             显示此帮助信息

场景说明:
    场景1: Percona(InnoDB) 主库 → MariaDB(ColumnStore) 从库  
    场景2: MariaDB(InnoDB) 主库 → Percona(RocksDB) 从库

EOF
}

# 检查系统要求
check_requirements() {
    log "检查系统要求..."
    
    local required_tools=("docker" "curl" "mysql" "mysqldump" "unzip")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "缺少必要工具: $tool"
        fi
    done
    
    # 检查端口是否被占用
    if netstat -tulpn 2>/dev/null | grep -q ":$PERCONA_PORT "; then
        error "端口 $PERCONA_PORT 已被占用"
    fi
    
    if netstat -tulpn 2>/dev/null | grep -q ":$MARIADB_PORT "; then
        error "端口 $MARIADB_PORT 已被占用"
    fi
    
    log "系统要求检查通过"
}

# 下载并准备 Percona Server
setup_percona() {
    log "准备 Percona Server 8.0..."
    
    local percona_dir="$SCRIPT_DIR/percona"
    mkdir -p "$percona_dir"
    
    if [[ ! -f "$percona_dir/percona80.xz" ]]; then
        log "下载 Percona Server..."
        curl -L "$PERCONA_URL" -o "$percona_dir/percona80.xz"
    fi
    
    if [[ ! -d "$percona_dir/mysql" ]]; then
        log "解压 Percona Server..."
        cd "$percona_dir"
        unzip -q percona80.xz || xz -d percona80.xz && tar -xf percona80.tar
        mv percona80-* mysql 2>/dev/null || true
    fi
    
    log "Percona Server 准备完成"
}

# 启动 Percona Server
start_percona() {
    local role="$1"  # master 或 slave
    local engine="$2"  # innodb 或 rocksdb
    
    log "启动 Percona Server ($role, $engine)..."
    
    local config_file="$SCRIPT_DIR/configs/percona-$role-$engine.cnf"
    local data_dir="$SCRIPT_DIR/data/percona-$role"
    
    mkdir -p "$data_dir"
    
    # 初始化数据目录
    if [[ ! -f "$data_dir/ibdata1" ]]; then
        "$SCRIPT_DIR/percona/mysql/bin/mysqld" --initialize-insecure \
            --datadir="$data_dir" \
            --basedir="$SCRIPT_DIR/percona/mysql"
    fi
    
    # 启动 MySQL 服务
    "$SCRIPT_DIR/percona/mysql/bin/mysqld_safe" \
        --defaults-file="$config_file" \
        --datadir="$data_dir" \
        --pid-file="$data_dir/mysql.pid" \
        --socket="$data_dir/mysql.sock" \
        --port="$PERCONA_PORT" &
    
    # 等待服务启动
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if "$SCRIPT_DIR/percona/mysql/bin/mysql" -h127.0.0.1 -P"$PERCONA_PORT" -uroot -e "SELECT 1" &>/dev/null; then
            log "Percona Server 启动成功"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
    done
    
    error "Percona Server 启动失败"
}

# 启动 MariaDB
start_mariadb() {
    local role="$1"  # master 或 slave
    local engine="$2"  # innodb 或 columnstore
    
    log "启动 MariaDB ($role, $engine)..."
    
    # 使用 Docker 运行 MariaDB
    local container_name="mariadb-$role"
    local config_mount="-v $SCRIPT_DIR/configs/mariadb-$role-$engine.cnf:/etc/mysql/conf.d/custom.cnf"
    
    docker run -d \
        --name "$container_name" \
        -p "$MARIADB_PORT:3306" \
        -e MYSQL_ROOT_PASSWORD=root \
        -e MYSQL_DATABASE="$TEST_DB" \
        $config_mount \
        mariadb:latest \
        --default-storage-engine="$engine"
    
    # 等待服务启动
    local retries=30
    while [[ $retries -gt 0 ]]; do
        if mysql -h127.0.0.1 -P"$MARIADB_PORT" -uroot -proot -e "SELECT 1" &>/dev/null; then
            log "MariaDB 启动成功"
            return 0
        fi
        sleep 2
        retries=$((retries - 1))
    done
    
    error "MariaDB 启动失败"
}

# 配置主从复制
setup_replication() {
    local master_type="$1"  # percona 或 mariadb
    local slave_type="$2"   # percona 或 mariadb
    
    log "配置主从复制: $master_type -> $slave_type"
    
    if [[ "$master_type" == "percona" ]]; then
        local master_port="$PERCONA_PORT"
        local master_cmd="$SCRIPT_DIR/percona/mysql/bin/mysql -h127.0.0.1 -P$master_port -uroot"
    else
        local master_port="$MARIADB_PORT"
        local master_cmd="mysql -h127.0.0.1 -P$master_port -uroot -proot"
    fi
    
    if [[ "$slave_type" == "percona" ]]; then
        local slave_port="$PERCONA_PORT"
        local slave_cmd="$SCRIPT_DIR/percona/mysql/bin/mysql -h127.0.0.1 -P$slave_port -uroot"
    else
        local slave_port="$MARIADB_PORT"
        local slave_cmd="mysql -h127.0.0.1 -P$slave_port -uroot -proot"
    fi
    
    # 在主库创建复制用户
    $master_cmd -e "
        CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'repl_password';
        GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
        FLUSH PRIVILEGES;
    "
    
    # 获取主库状态
    local master_status
    master_status=$($master_cmd -e "SHOW MASTER STATUS\\G")
    local master_file=$(echo "$master_status" | grep "File:" | awk '{print $2}')
    local master_pos=$(echo "$master_status" | grep "Position:" | awk '{print $2}')
    
    log "主库状态: File=$master_file, Position=$master_pos"
    
    # 配置从库
    $slave_cmd -e "
        STOP SLAVE;
        CHANGE MASTER TO
            MASTER_HOST='127.0.0.1',
            MASTER_PORT=$master_port,
            MASTER_USER='repl',
            MASTER_PASSWORD='repl_password',
            MASTER_LOG_FILE='$master_file',
            MASTER_LOG_POS=$master_pos;
        START SLAVE;
    "
    
    # 检查从库状态
    sleep 5
    local slave_status
    slave_status=$($slave_cmd -e "SHOW SLAVE STATUS\\G")
    
    if echo "$slave_status" | grep -q "Slave_IO_Running: Yes" && echo "$slave_status" | grep -q "Slave_SQL_Running: Yes"; then
        log "主从复制配置成功"
        return 0
    else
        log "主从复制配置失败"
        echo "$slave_status"
        return 1
    fi
}

# 运行同步测试
run_sync_test() {
    local scenario="$1"
    local test_name="scenario_$scenario"
    
    log "开始运行场景 $scenario 测试..."
    
    local start_time=$(date +%s)
    local test_result="$RESULTS_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).json"
    
    # 确定主从配置
    if [[ "$scenario" == "1" ]]; then
        local master_type="percona"
        local slave_type="mariadb"
        local master_engine="innodb"
        local slave_engine="columnstore"
        local master_port="$PERCONA_PORT"
        local slave_port="$MARIADB_PORT"
        local master_cmd="$SCRIPT_DIR/percona/mysql/bin/mysql -h127.0.0.1 -P$master_port -uroot"
        local slave_cmd="mysql -h127.0.0.1 -P$slave_port -uroot -proot"
    else
        local master_type="mariadb"
        local slave_type="percona"
        local master_engine="innodb"
        local slave_engine="rocksdb"
        local master_port="$MARIADB_PORT"
        local slave_port="$PERCONA_PORT"
        local master_cmd="mysql -h127.0.0.1 -P$master_port -uroot -proot"
        local slave_cmd="$SCRIPT_DIR/percona/mysql/bin/mysql -h127.0.0.1 -P$slave_port -uroot"
    fi
    
    # 启动数据库服务
    if [[ "$master_type" == "percona" ]]; then
        start_percona "master" "$master_engine"
        start_mariadb "slave" "$slave_engine"
    else
        start_mariadb "master" "$master_engine"
        start_percona "slave" "$slave_engine"
    fi
    
    # 配置主从复制
    if ! setup_replication "$master_type" "$slave_type"; then
        log "场景 $scenario 复制配置失败"
        return 1
    fi
    
    # 运行数据同步测试
    local test_results=()
    local errors=0
    local total_tests=0
    
    # 测试1: 基本插入同步
    log "测试基本插入同步..."
    $master_cmd -e "
        CREATE DATABASE IF NOT EXISTS $TEST_DB;
        USE $TEST_DB;
        CREATE TABLE sync_test (
            id INT PRIMARY KEY AUTO_INCREMENT,
            data VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=$master_engine;
    "
    
    for i in {1..10}; do
        $master_cmd -e "USE $TEST_DB; INSERT INTO sync_test (data) VALUES ('test_data_$i');"
        sleep 1
        
        # 检查从库同步
        local master_count=$($master_cmd -se "USE $TEST_DB; SELECT COUNT(*) FROM sync_test;")
        local slave_count=$($slave_cmd -se "USE $TEST_DB; SELECT COUNT(*) FROM sync_test;" 2>/dev/null || echo "0")
        
        total_tests=$((total_tests + 1))
        if [[ "$master_count" != "$slave_count" ]]; then
            log "同步失败: 主库 $master_count 条记录, 从库 $slave_count 条记录"
            errors=$((errors + 1))
        fi
    done
    
    # 测试2: 批量操作同步
    log "测试批量操作同步..."
    $master_cmd -e "
        USE $TEST_DB;
        INSERT INTO sync_test (data) VALUES 
        $(for i in {1..100}; do echo "('batch_$i')"; done | paste -sd,);
    "
    
    sleep 5
    local master_count=$($master_cmd -se "USE $TEST_DB; SELECT COUNT(*) FROM sync_test;")
    local slave_count=$($slave_cmd -se "USE $TEST_DB; SELECT COUNT(*) FROM sync_test;" 2>/dev/null || echo "0")
    
    total_tests=$((total_tests + 1))
    if [[ "$master_count" != "$slave_count" ]]; then
        log "批量同步失败: 主库 $master_count 条记录, 从库 $slave_count 条记录"
        errors=$((errors + 1))
    fi
    
    # 测试3: 延迟测量
    log "测试同步延迟..."
    local delays=()
    for i in {1..5}; do
        local insert_time=$(date +%s.%N)
        $master_cmd -e "USE $TEST_DB; INSERT INTO sync_test (data) VALUES ('delay_test_$i');"
        
        while true; do
            if $slave_cmd -se "USE $TEST_DB; SELECT COUNT(*) FROM sync_test WHERE data='delay_test_$i';" 2>/dev/null | grep -q "1"; then
                local sync_time=$(date +%s.%N)
                local delay=$(echo "$sync_time - $insert_time" | bc)
                delays+=("$delay")
                log "同步延迟: ${delay}s"
                break
            fi
            sleep 0.1
        done
    done
    
    local end_time=$(date +%s)
    local test_duration=$((end_time - start_time))
    
    # 计算平均延迟
    local avg_delay=0
    if [[ ${#delays[@]} -gt 0 ]]; then
        local sum_delay=0
        for delay in "${delays[@]}"; do
            sum_delay=$(echo "$sum_delay + $delay" | bc)
        done
        avg_delay=$(echo "scale=3; $sum_delay / ${#delays[@]}" | bc)
    fi
    
    # 生成测试结果
    cat > "$test_result" << EOF
{
    "scenario": $scenario,
    "master_type": "$master_type",
    "slave_type": "$slave_type",
    "master_engine": "$master_engine",
    "slave_engine": "$slave_engine",
    "test_duration": $test_duration,
    "total_tests": $total_tests,
    "errors": $errors,
    "success_rate": $(echo "scale=2; ($total_tests - $errors) * 100 / $total_tests" | bc),
    "average_delay": $avg_delay,
    "delays": [$(IFS=,; echo "${delays[*]}")],
    "final_master_count": $master_count,
    "final_slave_count": $slave_count,
    "sync_success": $([ "$master_count" == "$slave_count" ] && echo "true" || echo "false"),
    "timestamp": "$(date -Iseconds)"
}
EOF
    
    log "场景 $scenario 测试完成，结果保存到: $test_result"
    
    # 清理
    cleanup_scenario "$scenario"
    
    return $errors
}

# 清理测试环境
cleanup_scenario() {
    local scenario="$1"
    
    log "清理场景 $scenario 环境..."
    
    # 停止 Docker 容器
    docker stop mariadb-master 2>/dev/null || true
    docker stop mariadb-slave 2>/dev/null || true
    docker rm mariadb-master 2>/dev/null || true
    docker rm mariadb-slave 2>/dev/null || true
    
    # 停止 Percona 进程
    pkill -f mysqld || true
    
    # 清理数据目录
    rm -rf "$SCRIPT_DIR/data"
}

# 生成详细报告
generate_detailed_report() {
    log "生成详细测试报告..."
    
    local report_file="$RESULTS_DIR/detailed_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << 'EOF'
# 数据库主从同步测试详细报告

## 测试概述

本报告展示了 Percona Server 8.0 与 MariaDB 之间主从同步的测试结果。

## 测试环境

- 操作系统: Linux
- Percona Server: 8.0 (CentOS7 编译版本)
- MariaDB: 最新版本 (Docker)
- 测试时间: $(date)

## 测试场景

### 场景1: Percona(InnoDB) → MariaDB(ColumnStore)
### 场景2: MariaDB(InnoDB) → Percona(RocksDB)

## 测试结果

EOF
    
    # 添加每个场景的结果
    for result_file in "$RESULTS_DIR"/scenario_*.json; do
        if [[ -f "$result_file" ]]; then
            local scenario=$(jq -r '.scenario' "$result_file")
            local master_type=$(jq -r '.master_type' "$result_file")
            local slave_type=$(jq -r '.slave_type' "$result_file")
            local master_engine=$(jq -r '.master_engine' "$result_file")
            local slave_engine=$(jq -r '.slave_engine' "$result_file")
            local success_rate=$(jq -r '.success_rate' "$result_file")
            local avg_delay=$(jq -r '.average_delay' "$result_file")
            local sync_success=$(jq -r '.sync_success' "$result_file")
            
            cat >> "$report_file" << EOF

### 场景 $scenario: $master_type($master_engine) → $slave_type($slave_engine)

- **同步成功**: $sync_success
- **成功率**: $success_rate%
- **平均延迟**: ${avg_delay}s
- **测试时间**: $(jq -r '.timestamp' "$result_file")

#### 详细指标

\`\`\`json
$(cat "$result_file")
\`\`\`

EOF
        fi
    done
    
    # 添加对比分析
    cat >> "$report_file" << 'EOF'

## 稳定性对比分析

### 同步延迟对比

| 场景 | 主库类型 | 从库类型 | 平均延迟(s) | 最大延迟(s) | 最小延迟(s) |
|------|----------|----------|-------------|-------------|-------------|
EOF
    
    for result_file in "$RESULTS_DIR"/scenario_*.json; do
        if [[ -f "$result_file" ]]; then
            local scenario=$(jq -r '.scenario' "$result_file")
            local master_type=$(jq -r '.master_type' "$result_file")
            local slave_type=$(jq -r '.slave_type' "$result_file")
            local avg_delay=$(jq -r '.average_delay' "$result_file")
            local delays=$(jq -r '.delays[]' "$result_file" | tr '\n' ' ')
            local max_delay=$(echo "$delays" | tr ' ' '\n' | sort -n | tail -1)
            local min_delay=$(echo "$delays" | tr ' ' '\n' | sort -n | head -1)
            
            echo "| 场景$scenario | $master_type | $slave_type | $avg_delay | $max_delay | $min_delay |" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << 'EOF'

### 错误率对比

| 场景 | 总测试数 | 错误数 | 成功率 | 数据一致性 |
|------|----------|--------|--------|------------|
EOF
    
    for result_file in "$RESULTS_DIR"/scenario_*.json; do
        if [[ -f "$result_file" ]]; then
            local scenario=$(jq -r '.scenario' "$result_file")
            local total_tests=$(jq -r '.total_tests' "$result_file")
            local errors=$(jq -r '.errors' "$result_file")
            local success_rate=$(jq -r '.success_rate' "$result_file")
            local sync_success=$(jq -r '.sync_success' "$result_file")
            
            echo "| 场景$scenario | $total_tests | $errors | $success_rate% | $sync_success |" >> "$report_file"
        fi
    done
    
    cat >> "$report_file" << 'EOF'

## 建议

基于测试结果，提供以下建议：

1. **性能优化**: 根据延迟测试结果调整配置参数
2. **监控设置**: 建立主从延迟监控告警
3. **故障恢复**: 制定主从切换应急预案
4. **定期检查**: 建议定期运行一致性检查

## 结论

EOF
    
    # 添加结论
    local total_scenarios=$(ls "$RESULTS_DIR"/scenario_*.json 2>/dev/null | wc -l)
    local successful_scenarios=0
    
    for result_file in "$RESULTS_DIR"/scenario_*.json; do
        if [[ -f "$result_file" ]]; then
            if [[ "$(jq -r '.sync_success' "$result_file")" == "true" ]]; then
                successful_scenarios=$((successful_scenarios + 1))
            fi
        fi
    done
    
    echo "测试完成。$total_scenarios 个场景中有 $successful_scenarios 个场景同步成功。" >> "$report_file"
    
    log "详细报告已生成: $report_file"
}

# 主函数
main() {
    local scenario=""
    local detailed_report=false
    local cleanup=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --scenario=*)
                scenario="${1#*=}"
                shift
                ;;
            --detailed-report)
                detailed_report=true
                shift
                ;;
            --cleanup)
                cleanup=true
                shift
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
    
    if [[ "$cleanup" == "true" ]]; then
        cleanup_scenario "1"
        cleanup_scenario "2"
        log "清理完成"
        exit 0
    fi
    
    log "开始数据库主从同步测试..."
    
    # 检查系统要求
    check_requirements
    
    # 准备 Percona Server
    setup_percona
    
    local test_errors=0
    
    # 运行测试场景
    if [[ -z "$scenario" || "$scenario" == "1" ]]; then
        if ! run_sync_test "1"; then
            test_errors=$((test_errors + 1))
        fi
    fi
    
    if [[ -z "$scenario" || "$scenario" == "2" ]]; then
        if ! run_sync_test "2"; then
            test_errors=$((test_errors + 1))
        fi
    fi
    
    # 生成报告
    if [[ "$detailed_report" == "true" ]] || [[ -z "$scenario" ]]; then
        generate_detailed_report
    fi
    
    if [[ $test_errors -eq 0 ]]; then
        log "所有测试完成，无错误"
        exit 0
    else
        log "测试完成，共 $test_errors 个场景失败"
        exit 1
    fi
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi