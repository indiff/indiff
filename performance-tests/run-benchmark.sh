#!/bin/bash
# MySQL性能基准测试脚本
# 使用sysbench和自定义测试对不同数据库和存储引擎进行性能测试

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="/tmp/mysql-performance-test"
RESULTS_DIR="$ROOT_DIR/performance-results"
LOG_DIR="$RESULTS_DIR/logs"

# 测试配置
TEST_DURATION=300  # 5分钟
THREADS_LIST=(1 2 4 8 16 32)
TABLE_SIZE=1000000  # 100万行数据

# 数据库配置
declare -A DB_PORTS=(
    ["fbmysql-centos7"]=3306
    ["mariadb-centos7"]=3307
    ["omysql-centos7"]=3308
    ["percona80-centos7"]=3309
    ["percona80-ubuntu"]=3310
)

declare -A DB_NAMES=(
    ["fbmysql-centos7"]="Facebook MySQL 5.6"
    ["mariadb-centos7"]="MariaDB 10.x"
    ["omysql-centos7"]="Oracle MySQL 8.0"
    ["percona80-centos7"]="Percona Server 8.0"
    ["percona80-ubuntu"]="Percona Server 8.0 (Ubuntu)"
)

# 支持的存储引擎
declare -A STORAGE_ENGINES=(
    ["fbmysql-centos7"]="InnoDB MyISAM RocksDB"
    ["mariadb-centos7"]="InnoDB MyISAM RocksDB"
    ["omysql-centos7"]="InnoDB MyISAM"
    ["percona80-centos7"]="InnoDB MyISAM RocksDB"
    ["percona80-ubuntu"]="InnoDB MyISAM RocksDB"
)

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/benchmark.log"
}

error() {
    echo "[ERROR] $*" >&2 | tee -a "$LOG_DIR/benchmark.log"
    exit 1
}

# 等待数据库就绪
wait_for_database() {
    local db_key="$1"
    local port="${DB_PORTS[$db_key]}"
    local socket="$WORK_DIR/$db_key/data/mysql.sock"
    
    log "等待 ${DB_NAMES[$db_key]} 就绪..."
    
    local max_wait=60
    local count=0
    while [[ $count -lt $max_wait ]]; do
        if mysql -h127.0.0.1 -P"$port" -uroot -e "SELECT 1;" &>/dev/null; then
            log "${DB_NAMES[$db_key]} 已就绪"
            return 0
        fi
        if [[ -S "$socket" ]] && mysql -S"$socket" -uroot -e "SELECT 1;" &>/dev/null; then
            log "${DB_NAMES[$db_key]} 已就绪 (通过socket)"
            return 0
        fi
        sleep 2
        ((count+=2))
    done
    
    error "${DB_NAMES[$db_key]} 未能就绪"
}

# 创建测试数据库
create_test_database() {
    local db_key="$1"
    local engine="$2"
    local port="${DB_PORTS[$db_key]}"
    local socket="$WORK_DIR/$db_key/data/mysql.sock"
    local db_name="benchmark_${engine,,}"
    
    log "创建测试数据库: $db_name (${DB_NAMES[$db_key]}, $engine)"
    
    # 尝试TCP连接，失败则使用socket
    local mysql_cmd="mysql -h127.0.0.1 -P$port -uroot"
    if ! $mysql_cmd -e "SELECT 1;" &>/dev/null; then
        if [[ -S "$socket" ]]; then
            mysql_cmd="mysql -S$socket -uroot"
        else
            error "无法连接到 ${DB_NAMES[$db_key]}"
        fi
    fi
    
    # 创建数据库
    $mysql_cmd -e "DROP DATABASE IF EXISTS $db_name;" || true
    $mysql_cmd -e "CREATE DATABASE $db_name;"
    
    # 设置默认存储引擎
    $mysql_cmd -e "SET GLOBAL default_storage_engine='$engine';" || true
    
    echo "$mysql_cmd" > "$RESULTS_DIR/${db_key}_${engine,,}_mysql_cmd.txt"
}

# 运行sysbench测试
run_sysbench_test() {
    local db_key="$1"
    local engine="$2"
    local test_name="$3"
    local threads="$4"
    local port="${DB_PORTS[$db_key]}"
    local socket="$WORK_DIR/$db_key/data/mysql.sock"
    local db_name="benchmark_${engine,,}"
    local result_file="$RESULTS_DIR/${db_key}_${engine,,}_${test_name}_t${threads}.json"
    
    log "运行 $test_name 测试: ${DB_NAMES[$db_key]}, $engine, $threads 线程"
    
    # 准备sysbench连接参数
    local sysbench_params=""
    if netstat -ln 2>/dev/null | grep -q ":$port "; then
        sysbench_params="--mysql-host=127.0.0.1 --mysql-port=$port"
    elif [[ -S "$socket" ]]; then
        sysbench_params="--mysql-socket=$socket"
    else
        log "警告: 无法连接到 ${DB_NAMES[$db_key]}, 跳过测试"
        return 1
    fi
    
    # 准备测试数据（仅对第一个线程数执行）
    if [[ "$threads" == "${THREADS_LIST[0]}" ]]; then
        log "准备测试数据..."
        sysbench $test_name prepare \
            $sysbench_params \
            --mysql-user=root \
            --mysql-db="$db_name" \
            --table-size=$TABLE_SIZE \
            --tables=16 \
            --threads=$threads \
            --mysql-storage-engine=$engine || {
            log "准备数据失败，跳过测试"
            return 1
        }
    fi
    
    # 运行基准测试
    log "执行性能测试..."
    sysbench $test_name run \
        $sysbench_params \
        --mysql-user=root \
        --mysql-db="$db_name" \
        --table-size=$TABLE_SIZE \
        --tables=16 \
        --threads=$threads \
        --time=$TEST_DURATION \
        --report-interval=10 \
        --mysql-storage-engine=$engine \
        --db-ps-mode=disable > "$result_file" 2>&1 || {
        log "性能测试失败: $test_name"
        return 1
    }
    
    log "测试完成: $result_file"
}

# 运行自定义SQL性能测试
run_custom_sql_test() {
    local db_key="$1"
    local engine="$2"
    local port="${DB_PORTS[$db_key]}"
    local socket="$WORK_DIR/$db_key/data/mysql.sock"
    local db_name="benchmark_${engine,,}"
    local result_file="$RESULTS_DIR/${db_key}_${engine,,}_custom_sql.json"
    
    log "运行自定义SQL测试: ${DB_NAMES[$db_key]}, $engine"
    
    # 确定MySQL连接方式
    local mysql_cmd="mysql -h127.0.0.1 -P$port -uroot"
    if ! $mysql_cmd -e "SELECT 1;" &>/dev/null; then
        if [[ -S "$socket" ]]; then
            mysql_cmd="mysql -S$socket -uroot"
        else
            log "无法连接到 ${DB_NAMES[$db_key]}, 跳过自定义测试"
            return 1
        fi
    fi
    
    # 创建测试表
    $mysql_cmd "$db_name" -e "
        CREATE TABLE IF NOT EXISTS custom_test (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100),
            value INT,
            data TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_name (name),
            INDEX idx_value (value)
        ) ENGINE=$engine;
    " || return 1
    
    # 准备测试数据
    log "插入测试数据..."
    local insert_start=$(date +%s.%N)
    for i in {1..10000}; do
        $mysql_cmd "$db_name" -e "
            INSERT INTO custom_test (name, value, data) VALUES 
            ('name_$i', $((RANDOM % 1000)), 'test data $i');
        " &
        if [[ $((i % 100)) -eq 0 ]]; then
            wait
        fi
    done
    wait
    local insert_end=$(date +%s.%N)
    local insert_time=$(echo "$insert_end - $insert_start" | bc -l)
    
    # SELECT 测试
    log "执行SELECT测试..."
    local select_start=$(date +%s.%N)
    for i in {1..1000}; do
        $mysql_cmd "$db_name" -e "SELECT * FROM custom_test WHERE value > $((RANDOM % 500)) LIMIT 10;" &>/dev/null
    done
    local select_end=$(date +%s.%N)
    local select_time=$(echo "$select_end - $select_start" | bc -l)
    
    # UPDATE 测试
    log "执行UPDATE测试..."
    local update_start=$(date +%s.%N)
    for i in {1..1000}; do
        $mysql_cmd "$db_name" -e "UPDATE custom_test SET value = $((RANDOM % 1000)) WHERE id = $((RANDOM % 10000 + 1));" &>/dev/null
    done
    local update_end=$(date +%s.%N)
    local update_time=$(echo "$update_end - $update_start" | bc -l)
    
    # 保存结果
    cat > "$result_file" << EOF
{
    "database": "${DB_NAMES[$db_key]}",
    "storage_engine": "$engine",
    "insert_time": $insert_time,
    "select_time": $select_time,
    "update_time": $update_time,
    "insert_ops_per_sec": $(echo "10000 / $insert_time" | bc -l),
    "select_ops_per_sec": $(echo "1000 / $select_time" | bc -l),
    "update_ops_per_sec": $(echo "1000 / $update_time" | bc -l)
}
EOF
    
    log "自定义SQL测试完成: $result_file"
}

# 运行稳定性测试
run_stability_test() {
    local db_key="$1"
    local engine="$2"
    local duration=3600  # 1小时稳定性测试
    local result_file="$RESULTS_DIR/${db_key}_${engine,,}_stability.json"
    
    log "运行稳定性测试: ${DB_NAMES[$db_key]}, $engine (时长: ${duration}秒)"
    
    local port="${DB_PORTS[$db_key]}"
    local socket="$WORK_DIR/$db_key/data/mysql.sock"
    local db_name="benchmark_${engine,,}"
    
    # 准备sysbench连接参数
    local sysbench_params=""
    if netstat -ln 2>/dev/null | grep -q ":$port "; then
        sysbench_params="--mysql-host=127.0.0.1 --mysql-port=$port"
    elif [[ -S "$socket" ]]; then
        sysbench_params="--mysql-socket=$socket"
    else
        log "无法连接到 ${DB_NAMES[$db_key]}, 跳过稳定性测试"
        return 1
    fi
    
    # 运行长时间混合负载测试
    sysbench oltp_read_write run \
        $sysbench_params \
        --mysql-user=root \
        --mysql-db="$db_name" \
        --table-size=$TABLE_SIZE \
        --tables=16 \
        --threads=8 \
        --time=$duration \
        --report-interval=60 \
        --mysql-storage-engine=$engine > "$result_file" 2>&1 || {
        log "稳定性测试失败"
        return 1
    }
    
    log "稳定性测试完成: $result_file"
}

# 主测试函数
run_all_tests() {
    log "开始运行MySQL性能基准测试..."
    
    mkdir -p "$RESULTS_DIR" "$LOG_DIR"
    
    # 测试每个数据库
    for db_key in "${!DB_NAMES[@]}"; do
        log "========== 测试 ${DB_NAMES[$db_key]} =========="
        
        # 启动数据库
        bash "$ROOT_DIR/mysql-performance-test.sh" <<< "start_database $db_key ${DB_PORTS[$db_key]}" || {
            log "启动数据库失败: $db_key"
            continue
        }
        
        # 等待数据库就绪
        wait_for_database "$db_key" || continue
        
        # 测试每个存储引擎
        for engine in ${STORAGE_ENGINES[$db_key]}; do
            log "---------- 测试存储引擎: $engine ----------"
            
            # 创建测试数据库
            create_test_database "$db_key" "$engine" || continue
            
            # 运行sysbench测试
            local sysbench_tests=("oltp_read_only" "oltp_write_only" "oltp_read_write" "oltp_point_select" "oltp_insert")
            
            for test in "${sysbench_tests[@]}"; do
                for threads in "${THREADS_LIST[@]}"; do
                    run_sysbench_test "$db_key" "$engine" "$test" "$threads" || continue
                done
            done
            
            # 运行自定义SQL测试
            run_custom_sql_test "$db_key" "$engine" || continue
            
            # 运行稳定性测试（仅对InnoDB引擎）
            if [[ "$engine" == "InnoDB" ]]; then
                run_stability_test "$db_key" "$engine" || continue
            fi
        done
        
        # 停止数据库
        bash "$ROOT_DIR/mysql-performance-test.sh" <<< "stop_database $db_key" || true
        
        log "========== ${DB_NAMES[$db_key]} 测试完成 =========="
    done
    
    log "所有性能测试完成！"
    log "结果保存在: $RESULTS_DIR"
}

# 主函数
main() {
    local action="${1:-test}"
    
    case "$action" in
        "test")
            run_all_tests
            ;;
        *)
            echo "MySQL性能基准测试"
            echo "用法: $0 [test]"
            ;;
    esac
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi