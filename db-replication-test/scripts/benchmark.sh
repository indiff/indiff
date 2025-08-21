#!/bin/bash

# 性能基准测试脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"

# 配置
PERCONA_PORT=${PERCONA_PORT:-3306}
MARIADB_PORT=${MARIADB_PORT:-3307}
TEST_DURATION=${TEST_DURATION:-60}
CONCURRENT_THREADS=${CONCURRENT_THREADS:-4}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# 性能测试：插入操作
benchmark_insert() {
    local db_type="$1"
    local port="$2"
    local engine="$3"
    
    log "开始插入性能测试: $db_type ($engine)"
    
    if [[ "$db_type" == "percona" ]]; then
        local mysql_cmd="$SCRIPT_DIR/../percona/mysql/bin/mysql -h127.0.0.1 -P$port -uroot"
    else
        local mysql_cmd="mysql -h127.0.0.1 -P$port -uroot -proot"
    fi
    
    # 创建测试表
    $mysql_cmd -e "
        CREATE DATABASE IF NOT EXISTS benchmark_test;
        USE benchmark_test;
        DROP TABLE IF EXISTS insert_test;
        CREATE TABLE insert_test (
            id BIGINT PRIMARY KEY AUTO_INCREMENT,
            data1 VARCHAR(255),
            data2 TEXT,
            data3 DECIMAL(10,2),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=$engine;
    "
    
    local start_time=$(date +%s)
    local insert_count=0
    local end_time=$((start_time + TEST_DURATION))
    
    # 并发插入测试
    local pids=()
    for ((i=1; i<=CONCURRENT_THREADS; i++)); do
        (
            local thread_inserts=0
            while [[ $(date +%s) -lt $end_time ]]; do
                $mysql_cmd -e "
                    USE benchmark_test;
                    INSERT INTO insert_test (data1, data2, data3) VALUES
                    (CONCAT('thread_${i}_', UUID()), REPEAT('data', 100), RAND() * 1000);
                " 2>/dev/null || true
                thread_inserts=$((thread_inserts + 1))
            done
            echo "$thread_inserts" > "/tmp/thread_${i}_inserts.txt"
        ) &
        pids+=($!)
    done
    
    # 等待所有线程完成
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # 统计结果
    for ((i=1; i<=CONCURRENT_THREADS; i++)); do
        if [[ -f "/tmp/thread_${i}_inserts.txt" ]]; then
            local thread_count=$(cat "/tmp/thread_${i}_inserts.txt")
            insert_count=$((insert_count + thread_count))
            rm -f "/tmp/thread_${i}_inserts.txt"
        fi
    done
    
    local actual_duration=$(($(date +%s) - start_time))
    local inserts_per_second=$((insert_count / actual_duration))
    
    log "$db_type ($engine) 插入性能: $insert_count 条记录, $inserts_per_second 条/秒"
    
    # 返回性能数据
    echo "{\"db_type\":\"$db_type\",\"engine\":\"$engine\",\"operation\":\"insert\",\"total_ops\":$insert_count,\"duration\":$actual_duration,\"ops_per_second\":$inserts_per_second}"
}

# 性能测试：查询操作
benchmark_select() {
    local db_type="$1"
    local port="$2"
    local engine="$3"
    
    log "开始查询性能测试: $db_type ($engine)"
    
    if [[ "$db_type" == "percona" ]]; then
        local mysql_cmd="$SCRIPT_DIR/../percona/mysql/bin/mysql -h127.0.0.1 -P$port -uroot"
    else
        local mysql_cmd="mysql -h127.0.0.1 -P$port -uroot -proot"
    fi
    
    # 确保有测试数据
    local record_count
    record_count=$($mysql_cmd -se "USE benchmark_test; SELECT COUNT(*) FROM insert_test;" 2>/dev/null || echo "0")
    
    if [[ "$record_count" -eq 0 ]]; then
        log "警告: 没有测试数据，跳过查询测试"
        echo "{\"db_type\":\"$db_type\",\"engine\":\"$engine\",\"operation\":\"select\",\"total_ops\":0,\"duration\":0,\"ops_per_second\":0}"
        return
    fi
    
    local start_time=$(date +%s)
    local select_count=0
    local end_time=$((start_time + TEST_DURATION))
    
    # 并发查询测试
    local pids=()
    for ((i=1; i<=CONCURRENT_THREADS; i++)); do
        (
            local thread_selects=0
            while [[ $(date +%s) -lt $end_time ]]; do
                local random_id=$((RANDOM % record_count + 1))
                $mysql_cmd -e "
                    USE benchmark_test;
                    SELECT * FROM insert_test WHERE id = $random_id;
                    SELECT COUNT(*) FROM insert_test WHERE data3 > 500;
                    SELECT * FROM insert_test ORDER BY created_at DESC LIMIT 10;
                " >/dev/null 2>&1 || true
                thread_selects=$((thread_selects + 3))  # 3个查询
            done
            echo "$thread_selects" > "/tmp/thread_${i}_selects.txt"
        ) &
        pids+=($!)
    done
    
    # 等待所有线程完成
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # 统计结果
    for ((i=1; i<=CONCURRENT_THREADS; i++)); do
        if [[ -f "/tmp/thread_${i}_selects.txt" ]]; then
            local thread_count=$(cat "/tmp/thread_${i}_selects.txt")
            select_count=$((select_count + thread_count))
            rm -f "/tmp/thread_${i}_selects.txt"
        fi
    done
    
    local actual_duration=$(($(date +%s) - start_time))
    local selects_per_second=$((select_count / actual_duration))
    
    log "$db_type ($engine) 查询性能: $select_count 次查询, $selects_per_second 次/秒"
    
    echo "{\"db_type\":\"$db_type\",\"engine\":\"$engine\",\"operation\":\"select\",\"total_ops\":$select_count,\"duration\":$actual_duration,\"ops_per_second\":$selects_per_second}"
}

# 性能测试：更新操作
benchmark_update() {
    local db_type="$1"
    local port="$2"
    local engine="$3"
    
    log "开始更新性能测试: $db_type ($engine)"
    
    if [[ "$db_type" == "percona" ]]; then
        local mysql_cmd="$SCRIPT_DIR/../percona/mysql/bin/mysql -h127.0.0.1 -P$port -uroot"
    else
        local mysql_cmd="mysql -h127.0.0.1 -P$port -uroot -proot"
    fi
    
    local record_count
    record_count=$($mysql_cmd -se "USE benchmark_test; SELECT COUNT(*) FROM insert_test;" 2>/dev/null || echo "0")
    
    if [[ "$record_count" -eq 0 ]]; then
        log "警告: 没有测试数据，跳过更新测试"
        echo "{\"db_type\":\"$db_type\",\"engine\":\"$engine\",\"operation\":\"update\",\"total_ops\":0,\"duration\":0,\"ops_per_second\":0}"
        return
    fi
    
    local start_time=$(date +%s)
    local update_count=0
    local end_time=$((start_time + TEST_DURATION))
    
    # 并发更新测试
    local pids=()
    for ((i=1; i<=CONCURRENT_THREADS; i++)); do
        (
            local thread_updates=0
            while [[ $(date +%s) -lt $end_time ]]; do
                local random_id=$((RANDOM % record_count + 1))
                $mysql_cmd -e "
                    USE benchmark_test;
                    UPDATE insert_test SET data3 = RAND() * 1000 WHERE id = $random_id;
                " 2>/dev/null || true
                thread_updates=$((thread_updates + 1))
            done
            echo "$thread_updates" > "/tmp/thread_${i}_updates.txt"
        ) &
        pids+=($!)
    done
    
    # 等待所有线程完成
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    # 统计结果
    for ((i=1; i<=CONCURRENT_THREADS; i++)); do
        if [[ -f "/tmp/thread_${i}_updates.txt" ]]; then
            local thread_count=$(cat "/tmp/thread_${i}_updates.txt")
            update_count=$((update_count + thread_count))
            rm -f "/tmp/thread_${i}_updates.txt"
        fi
    done
    
    local actual_duration=$(($(date +%s) - start_time))
    local updates_per_second=$((update_count / actual_duration))
    
    log "$db_type ($engine) 更新性能: $update_count 次更新, $updates_per_second 次/秒"
    
    echo "{\"db_type\":\"$db_type\",\"engine\":\"$engine\",\"operation\":\"update\",\"total_ops\":$update_count,\"duration\":$actual_duration,\"ops_per_second\":$updates_per_second}"
}

# 运行完整基准测试
run_full_benchmark() {
    local scenario="$1"
    
    log "开始场景 $scenario 性能基准测试..."
    
    local benchmark_file="$RESULTS_DIR/benchmark_scenario_${scenario}_$(date +%Y%m%d_%H%M%S).json"
    
    echo "[" > "$benchmark_file"
    
    if [[ "$scenario" == "1" ]]; then
        # 场景1: Percona(InnoDB) → MariaDB(ColumnStore)
        
        # 测试 Percona InnoDB 性能
        benchmark_insert "percona" "$PERCONA_PORT" "innodb" >> "$benchmark_file"
        echo "," >> "$benchmark_file"
        benchmark_select "percona" "$PERCONA_PORT" "innodb" >> "$benchmark_file"
        echo "," >> "$benchmark_file"
        benchmark_update "percona" "$PERCONA_PORT" "innodb" >> "$benchmark_file"
        echo "," >> "$benchmark_file"
        
        # 测试 MariaDB ColumnStore 性能
        benchmark_insert "mariadb" "$MARIADB_PORT" "columnstore" >> "$benchmark_file"
        echo "," >> "$benchmark_file"
        benchmark_select "mariadb" "$MARIADB_PORT" "columnstore" >> "$benchmark_file"
        echo "," >> "$benchmark_file"
        benchmark_update "mariadb" "$MARIADB_PORT" "columnstore" >> "$benchmark_file"
        
    else
        # 场景2: MariaDB(InnoDB) → Percona(RocksDB)
        
        # 测试 MariaDB InnoDB 性能
        benchmark_insert "mariadb" "$MARIADB_PORT" "innodb" >> "$benchmark_file"
        echo "," >> "$benchmark_file"
        benchmark_select "mariadb" "$MARIADB_PORT" "innodb" >> "$benchmark_file"
        echo "," >> "$benchmark_file"
        benchmark_update "mariadb" "$MARIADB_PORT" "innodb" >> "$benchmark_file"
        echo "," >> "$benchmark_file"
        
        # 测试 Percona RocksDB 性能
        benchmark_insert "percona" "$PERCONA_PORT" "rocksdb" >> "$benchmark_file"
        echo "," >> "$benchmark_file"
        benchmark_select "percona" "$PERCONA_PORT" "rocksdb" >> "$benchmark_file"
        echo "," >> "$benchmark_file"
        benchmark_update "percona" "$PERCONA_PORT" "rocksdb" >> "$benchmark_file"
    fi
    
    echo "]" >> "$benchmark_file"
    
    log "基准测试完成，结果保存到: $benchmark_file"
}

# 主函数
main() {
    local scenario="${1:-1}"
    
    case "$scenario" in
        "1"|"2")
            run_full_benchmark "$scenario"
            ;;
        "help"|"--help")
            cat << EOF
性能基准测试脚本

用法:
    $0 [场景号]

场景:
    1    场景1基准测试 (Percona InnoDB + MariaDB ColumnStore)
    2    场景2基准测试 (MariaDB InnoDB + Percona RocksDB)

环境变量:
    TEST_DURATION       每个测试持续时间秒数 (默认: 60)
    CONCURRENT_THREADS  并发线程数 (默认: 4)
    PERCONA_PORT        Percona 端口 (默认: 3306)
    MARIADB_PORT        MariaDB 端口 (默认: 3307)

EOF
            ;;
        *)
            echo "无效的场景号: $scenario"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi