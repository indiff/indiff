#!/bin/bash

# Enhanced MySQL vs Percona vs MariaDB Performance Testing Script
# 三数据库并发性能测试：MySQL, Percona (with RocksDB), MariaDB (with ColumnStore)
# 对比不同存储引擎：InnoDB, RocksDB, ColumnStore

set -e

# 配置变量
MYSQL_VERSION=${MYSQL_VERSION:-"8.0"}
PERCONA_VERSION=${PERCONA_VERSION:-"8.0"}
MARIADB_VERSION=${MARIADB_VERSION:-"latest"}
TEST_DATABASE=${TEST_DATABASE:-"performance_test"}
TEST_DURATION=${TEST_DURATION:-300}  # 5分钟测试
THREADS_LIST=${THREADS_LIST:-"1 4 8 16 32 64"}
TABLE_SIZE=${TABLE_SIZE:-100000}
REPORT_DIR=${REPORT_DIR:-"$(pwd)/performance_reports"}

# 数据库和存储引擎配置
DATABASES=("mysql" "percona" "mariadb")
MYSQL_ENGINES=("innodb")
PERCONA_ENGINES=("innodb" "rocksdb")
MARIADB_ENGINES=("innodb" "columnstore")

# 端口配置
declare -A DB_PORTS
DB_PORTS["mysql"]=3306
DB_PORTS["percona"]=3307
DB_PORTS["mariadb"]=3308

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# 检查依赖
check_dependencies() {
    log "检查必要的依赖..."
    
    local deps=("docker" "docker-compose" "sysbench" "jq")
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

# 启动数据库容器
start_database_containers() {
    log "启动数据库容器..."
    
    # 检查并构建 Percona 自定义镜像
    if ! docker images | grep -q "indiff_percona_custom"; then
        log_info "构建 Percona 自定义镜像..."
        docker-compose build percona
    fi
    
    docker-compose up -d mysql percona mariadb
    
    # 等待所有数据库启动
    for db in "${DATABASES[@]}"; do
        local port=${DB_PORTS[$db]}
        local container_name="${db}_performance_test"
        
        log "等待 $db 数据库启动..."
        local retry_count=0
        local max_retries=60
        
        while [ $retry_count -lt $max_retries ]; do
            if docker exec "$container_name" mysqladmin ping -h localhost -u root -ptest123 &>/dev/null; then
                log "$db 数据库已启动"
                break
            fi
            sleep 2
            ((retry_count++))
        done
        
        if [ $retry_count -eq $max_retries ]; then
            log_error "$db 数据库启动超时"
            return 1
        fi
        
        # 创建测试用户和数据库
        docker exec "$container_name" mysql -u root -ptest123 -e "
            CREATE DATABASE IF NOT EXISTS $TEST_DATABASE;
            CREATE USER IF NOT EXISTS 'testuser'@'%' IDENTIFIED BY 'testpass';
            GRANT ALL PRIVILEGES ON $TEST_DATABASE.* TO 'testuser'@'%';
            FLUSH PRIVILEGES;
        "
    done
    
    log "所有数据库容器启动成功"
}

# 检查存储引擎可用性
check_storage_engines() {
    local db_type=$1
    local container_name="${db_type}_performance_test"
    
    log_info "检查 $db_type 可用的存储引擎..."
    
    case $db_type in
        "mysql")
            # MySQL 通常只支持 InnoDB
            echo "innodb"
            ;;
        "percona")
            # 检查 RocksDB 是否可用
            if docker exec "$container_name" mysql -u root -ptest123 -e "SHOW ENGINES;" | grep -i rocksdb | grep -i yes; then
                echo "innodb rocksdb"
            else
                log_warn "Percona RocksDB 引擎不可用，只使用 InnoDB"
                echo "innodb"
            fi
            ;;
        "mariadb")
            local engines="innodb"
            # 检查 ColumnStore 是否可用
            if docker exec "$container_name" mysql -u root -ptest123 -e "SHOW ENGINES;" | grep -i columnstore | grep -i yes; then
                engines="$engines columnstore"
            else
                log_warn "MariaDB ColumnStore 引擎不可用，只使用 InnoDB"
            fi
            echo "$engines"
            ;;
    esac
}

# 准备测试数据
prepare_test_data() {
    local db_type=$1
    local port=$2
    local engine=$3
    local test_type=$4
    
    log "为 $db_type ($engine) 准备 $test_type 测试数据..."
    
    # 删除现有表
    sysbench "$test_type" \
        --mysql-host=127.0.0.1 \
        --mysql-port="$port" \
        --mysql-user=testuser \
        --mysql-password=testpass \
        --mysql-db="$TEST_DATABASE" \
        --tables=10 \
        --table-size="$TABLE_SIZE" \
        cleanup &>/dev/null || true
    
    # 创建新表
    if [ "$engine" = "columnstore" ]; then
        # ColumnStore 需要特殊处理
        prepare_columnstore_data "$db_type" "$port"
    else
        # 普通存储引擎
        sysbench "$test_type" \
            --mysql-host=127.0.0.1 \
            --mysql-port="$port" \
            --mysql-user=testuser \
            --mysql-password=testpass \
            --mysql-db="$TEST_DATABASE" \
            --tables=10 \
            --table-size="$TABLE_SIZE" \
            --mysql-storage-engine="$engine" \
            prepare
    fi
    
    log "$db_type ($engine) $test_type 测试数据准备完成"
}

# 准备 ColumnStore 测试数据
prepare_columnstore_data() {
    local db_type=$1
    local port=$2
    
    log_info "为 ColumnStore 准备专门的测试数据..."
    
    # ColumnStore 适合分析型工作负载，创建适合的表结构
    mysql -h 127.0.0.1 -P "$port" -u testuser -ptestpass "$TEST_DATABASE" <<EOF
    DROP TABLE IF EXISTS columnstore_test;
    CREATE TABLE columnstore_test (
        id bigint auto_increment,
        k int not null default 0,
        c char(120) not null default '',
        pad char(60) not null default '',
        primary key(id),
        key k_idx (k)
    ) ENGINE=ColumnStore DEFAULT CHARSET=utf8mb4;
    
    INSERT INTO columnstore_test (k, c, pad) 
    SELECT 
        FLOOR(RAND() * $TABLE_SIZE) as k,
        REPEAT(CHAR(65 + FLOOR(RAND() * 26)), 120) as c,
        REPEAT(CHAR(65 + FLOOR(RAND() * 26)), 60) as pad
    FROM information_schema.columns c1, information_schema.columns c2
    LIMIT $TABLE_SIZE;
EOF
}

# 运行性能测试
run_performance_test() {
    local db_type=$1
    local port=$2
    local engine=$3
    local threads=$4
    local test_type=$5
    
    log "运行 $db_type ($engine) 性能测试: $test_type (线程数: $threads)"
    
    local output_file="$CURRENT_REPORT_DIR/${db_type}_${engine}_${test_type}_threads_${threads}.json"
    
    if [ "$engine" = "columnstore" ] && [ "$test_type" = "oltp_read_write" ]; then
        # ColumnStore 主要优化读性能，使用只读测试
        run_columnstore_test "$db_type" "$port" "$threads" "$output_file"
    else
        # 标准 sysbench 测试
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
    fi
    
    log "$db_type ($engine) $test_type 测试完成 (线程数: $threads)"
}

# 运行 ColumnStore 专门测试
run_columnstore_test() {
    local db_type=$1
    local port=$2
    local threads=$3
    local output_file=$4
    
    log_info "运行 ColumnStore 分析型查询测试..."
    
    # 创建自定义的分析型查询测试
    local start_time=$(date +%s)
    
    # 并发执行分析查询
    for i in $(seq 1 "$threads"); do
        (
            for j in $(seq 1 100); do
                mysql -h 127.0.0.1 -P "$port" -u testuser -ptestpass "$TEST_DATABASE" -e "
                    SELECT k, COUNT(*), AVG(id), MAX(id), MIN(id) 
                    FROM columnstore_test 
                    WHERE k BETWEEN FLOOR(RAND() * 1000) AND FLOOR(RAND() * 1000) + 100 
                    GROUP BY k 
                    ORDER BY COUNT(*) DESC 
                    LIMIT 10;
                " &>/dev/null
            done
        ) &
    done
    
    wait
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local tps=$(echo "scale=2; ($threads * 100) / $duration" | bc -l)
    
    # 生成兼容的输出格式
    cat > "$output_file" << EOF
ColumnStore Analytical Query Test Results:
Threads: $threads
Duration: ${duration}s
Total queries: $((threads * 100))
Transactions per second: $tps
Average latency: $(echo "scale=2; $duration * 1000 / ($threads * 100)" | bc -l)ms
EOF
}

# 获取系统信息
collect_system_info() {
    local db_type=$1
    local container_name="${db_type}_performance_test"
    
    log "收集 $db_type 系统信息..."
    
    # 容器资源使用情况
    docker stats "$container_name" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" > "$CURRENT_REPORT_DIR/${db_type}_container_stats.txt"
    
    # MySQL状态信息
    docker exec "$container_name" mysql -u root -ptest123 -e "SHOW ENGINE INNODB STATUS\G" > "$CURRENT_REPORT_DIR/${db_type}_innodb_status.txt" 2>/dev/null || true
    docker exec "$container_name" mysql -u root -ptest123 -e "SHOW GLOBAL STATUS" > "$CURRENT_REPORT_DIR/${db_type}_global_status.txt"
    docker exec "$container_name" mysql -u root -ptest123 -e "SHOW GLOBAL VARIABLES" > "$CURRENT_REPORT_DIR/${db_type}_global_variables.txt"
    docker exec "$container_name" mysql -u root -ptest123 -e "SHOW ENGINES" > "$CURRENT_REPORT_DIR/${db_type}_engines.txt"
    
    # 如果是 Percona，收集 RocksDB 状态
    if [ "$db_type" = "percona" ]; then
        docker exec "$container_name" mysql -u root -ptest123 -e "SHOW ENGINE ROCKSDB STATUS\G" > "$CURRENT_REPORT_DIR/${db_type}_rocksdb_status.txt" 2>/dev/null || true
    fi
    
    log "$db_type 系统信息收集完成"
}

# 清理测试数据
cleanup_test_data() {
    local db_type=$1
    local port=$2
    local test_type=$3
    
    log "清理 $db_type $test_type 测试数据..."
    
    sysbench "$test_type" \
        --mysql-host=127.0.0.1 \
        --mysql-port="$port" \
        --mysql-user=testuser \
        --mysql-password=testpass \
        --mysql-db="$TEST_DATABASE" \
        --tables=10 \
        cleanup &>/dev/null || true
    
    # 清理 ColumnStore 测试表
    mysql -h 127.0.0.1 -P "$port" -u testuser -ptestpass "$TEST_DATABASE" -e "DROP TABLE IF EXISTS columnstore_test;" 2>/dev/null || true
    
    log "$db_type $test_type 测试数据清理完成"
}

# 停止容器
stop_containers() {
    log "停止数据库容器..."
    docker-compose down
    log "数据库容器已停止"
}

# 解析测试结果
parse_test_results() {
    local file=$1
    local engine=$2
    
    if [ "$engine" = "columnstore" ]; then
        # 解析 ColumnStore 结果
        local tps=$(grep "Transactions per second:" "$file" | awk '{print $4}')
        local latency=$(grep "Average latency:" "$file" | awk '{print $3}' | sed 's/ms//')
        echo "$tps $latency"
    else
        # 解析标准 sysbench 结果
        local tps=$(grep "transactions:" "$file" | grep -oE '[0-9]+\.[0-9]+' | head -1)
        local latency=$(grep "avg:" "$file" | grep -oE '[0-9]+\.[0-9]+' | head -1)
        echo "$tps $latency"
    fi
}

# 生成增强的测试报告
generate_enhanced_report() {
    log "生成增强的性能测试报告..."
    
    local report_file="$CURRENT_REPORT_DIR/comprehensive_performance_report.md"
    
    cat > "$report_file" << EOF
# MySQL vs Percona vs MariaDB 综合性能测试报告

测试时间: $(date '+%Y-%m-%d %H:%M:%S')
测试持续时间: ${TEST_DURATION}秒
表大小: ${TABLE_SIZE}行
线程数: ${THREADS_LIST}

## 测试环境

- **MySQL 版本**: ${MYSQL_VERSION}
- **Percona 版本**: ${PERCONA_VERSION} (包含 RocksDB 支持)
- **MariaDB 版本**: ${MARIADB_VERSION} (包含 ColumnStore 支持)
- **测试工具**: sysbench + 自定义分析查询
- **操作系统**: $(uname -a)

## 数据库存储引擎对比

| 数据库 | 支持的存储引擎 | 主要特点 |
|--------|---------------|----------|
| MySQL 8.0 | InnoDB | 通用事务型存储引擎，OLTP 优化 |
| Percona 8.0 | InnoDB, RocksDB | InnoDB + 写优化的 RocksDB 引擎 |
| MariaDB | InnoDB, ColumnStore | InnoDB + 分析型 ColumnStore 引擎 |

## 测试场景

1. **OLTP 读写混合测试** (oltp_read_write) - 适用于 InnoDB, RocksDB
2. **只读测试** (oltp_read_only) - 适用于所有引擎
3. **只写测试** (oltp_write_only) - 适用于 InnoDB, RocksDB  
4. **插入测试** (oltp_insert) - 适用于 InnoDB, RocksDB
5. **分析查询测试** (analytical_queries) - 专门针对 ColumnStore

EOF

    # 生成各种测试场景的结果表格
    local test_types=("oltp_read_write" "oltp_read_only" "oltp_write_only" "oltp_insert")
    
    for test_type in "${test_types[@]}"; do
        echo "## $test_type 测试结果" >> "$report_file"
        echo "" >> "$report_file"
        
        # 为每个存储引擎创建对比表
        echo "### InnoDB 存储引擎对比" >> "$report_file"
        echo "" >> "$report_file"
        echo "| 线程数 | MySQL (InnoDB) TPS | Percona (InnoDB) TPS | MariaDB (InnoDB) TPS | MySQL 延迟(ms) | Percona 延迟(ms) | MariaDB 延迟(ms) |" >> "$report_file"
        echo "|--------|-------------------|---------------------|---------------------|----------------|------------------|------------------|" >> "$report_file"
        
        for threads in $THREADS_LIST; do
            local mysql_file="$CURRENT_REPORT_DIR/mysql_innodb_${test_type}_threads_${threads}.json"
            local percona_file="$CURRENT_REPORT_DIR/percona_innodb_${test_type}_threads_${threads}.json"
            local mariadb_file="$CURRENT_REPORT_DIR/mariadb_innodb_${test_type}_threads_${threads}.json"
            
            if [[ -f "$mysql_file" && -f "$percona_file" && -f "$mariadb_file" ]]; then
                local mysql_results=($(parse_test_results "$mysql_file" "innodb"))
                local percona_results=($(parse_test_results "$percona_file" "innodb"))
                local mariadb_results=($(parse_test_results "$mariadb_file" "innodb"))
                
                echo "| $threads | ${mysql_results[0]:-N/A} | ${percona_results[0]:-N/A} | ${mariadb_results[0]:-N/A} | ${mysql_results[1]:-N/A} | ${percona_results[1]:-N/A} | ${mariadb_results[1]:-N/A} |" >> "$report_file"
            fi
        done
        
        echo "" >> "$report_file"
        
        # RocksDB 专门对比 (如果可用)
        if ls "$CURRENT_REPORT_DIR"/percona_rocksdb_* &>/dev/null; then
            echo "### RocksDB vs InnoDB (Percona)" >> "$report_file"
            echo "" >> "$report_file"
            echo "| 线程数 | Percona (InnoDB) TPS | Percona (RocksDB) TPS | 性能差异 | InnoDB 延迟(ms) | RocksDB 延迟(ms) |" >> "$report_file"
            echo "|--------|---------------------|----------------------|----------|-----------------|------------------|" >> "$report_file"
            
            for threads in $THREADS_LIST; do
                local innodb_file="$CURRENT_REPORT_DIR/percona_innodb_${test_type}_threads_${threads}.json"
                local rocksdb_file="$CURRENT_REPORT_DIR/percona_rocksdb_${test_type}_threads_${threads}.json"
                
                if [[ -f "$innodb_file" && -f "$rocksdb_file" ]]; then
                    local innodb_results=($(parse_test_results "$innodb_file" "innodb"))
                    local rocksdb_results=($(parse_test_results "$rocksdb_file" "rocksdb"))
                    
                    local improvement="N/A"
                    if [[ -n "${innodb_results[0]}" && -n "${rocksdb_results[0]}" && "${innodb_results[0]}" != "0" ]]; then
                        improvement=$(echo "scale=2; (${rocksdb_results[0]} - ${innodb_results[0]}) / ${innodb_results[0]} * 100" | bc -l 2>/dev/null || echo "N/A")
                        improvement="${improvement}%"
                    fi
                    
                    echo "| $threads | ${innodb_results[0]:-N/A} | ${rocksdb_results[0]:-N/A} | $improvement | ${innodb_results[1]:-N/A} | ${rocksdb_results[1]:-N/A} |" >> "$report_file"
                fi
            done
            echo "" >> "$report_file"
        fi
    done
    
    # ColumnStore 分析查询结果 (如果可用)
    if ls "$CURRENT_REPORT_DIR"/mariadb_columnstore_* &>/dev/null; then
        echo "## ColumnStore 分析查询性能" >> "$report_file"
        echo "" >> "$report_file"
        echo "ColumnStore 引擎专门针对分析型工作负载优化，以下是分析查询性能对比:" >> "$report_file"
        echo "" >> "$report_file"
        echo "| 线程数 | MariaDB (InnoDB) TPS | MariaDB (ColumnStore) TPS | 性能提升 | InnoDB 延迟(ms) | ColumnStore 延迟(ms) |" >> "$report_file"
        echo "|--------|---------------------|---------------------------|----------|-----------------|---------------------|" >> "$report_file"
        
        for threads in $THREADS_LIST; do
            local innodb_file="$CURRENT_REPORT_DIR/mariadb_innodb_oltp_read_only_threads_${threads}.json"
            local columnstore_file="$CURRENT_REPORT_DIR/mariadb_columnstore_oltp_read_write_threads_${threads}.json"
            
            if [[ -f "$innodb_file" && -f "$columnstore_file" ]]; then
                local innodb_results=($(parse_test_results "$innodb_file" "innodb"))
                local columnstore_results=($(parse_test_results "$columnstore_file" "columnstore"))
                
                local improvement="N/A"
                if [[ -n "${innodb_results[0]}" && -n "${columnstore_results[0]}" && "${innodb_results[0]}" != "0" ]]; then
                    improvement=$(echo "scale=2; (${columnstore_results[0]} - ${innodb_results[0]}) / ${innodb_results[0]} * 100" | bc -l 2>/dev/null || echo "N/A")
                    improvement="${improvement}%"
                fi
                
                echo "| $threads | ${innodb_results[0]:-N/A} | ${columnstore_results[0]:-N/A} | $improvement | ${innodb_results[1]:-N/A} | ${columnstore_results[1]:-N/A} |" >> "$report_file"
            fi
        done
        echo "" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## 总结和建议

### 存储引擎特点对比

1. **InnoDB**: 
   - 成熟稳定的事务型存储引擎
   - 适合 OLTP 工作负载
   - 读写平衡性能好

2. **RocksDB**: 
   - 基于 LSM-tree 的存储引擎
   - 写性能优秀，适合写密集型工作负载
   - 压缩率高，节省存储空间

3. **ColumnStore**:
   - 列式存储引擎，针对分析型查询优化
   - 适合大数据分析和 OLAP 工作负载
   - 不适合频繁的事务操作

### 选择建议

- **通用 OLTP 应用**: 选择 MySQL 8.0 或 Percona InnoDB
- **写密集型应用**: 考虑 Percona RocksDB
- **分析型应用**: 考虑 MariaDB ColumnStore
- **混合工作负载**: Percona Server 提供最佳的引擎选择灵活性

### 详细数据

所有详细的测试数据、系统信息和配置文件保存在同一目录下的其他文件中。

EOF

    log "增强的性能测试报告已生成: $report_file"
}

# 主函数
main() {
    log "开始 MySQL vs Percona vs MariaDB 综合性能测试"
    
    check_dependencies
    setup_report_dir
    start_database_containers
    
    # 测试场景列表
    local test_types=("oltp_read_write" "oltp_read_only" "oltp_write_only" "oltp_insert")
    
    # 为每个数据库运行测试
    for db_type in "${DATABASES[@]}"; do
        local port=${DB_PORTS[$db_type]}
        
        log "开始测试 $db_type..."
        
        # 获取可用的存储引擎
        local available_engines=($(check_storage_engines "$db_type"))
        log_info "$db_type 可用的存储引擎: ${available_engines[*]}"
        
        for engine in "${available_engines[@]}"; do
            log_info "测试 $db_type 的 $engine 存储引擎..."
            
            for test_type in "${test_types[@]}"; do
                # ColumnStore 不适合事务型测试，跳过部分测试
                if [ "$engine" = "columnstore" ] && [[ "$test_type" = *"write"* || "$test_type" = "oltp_insert" ]]; then
                    log_warn "跳过 ColumnStore 的 $test_type 测试（不适合事务型工作负载）"
                    continue
                fi
                
                log "准备 $test_type 测试..."
                prepare_test_data "$db_type" "$port" "$engine" "$test_type"
                
                for threads in $THREADS_LIST; do
                    run_performance_test "$db_type" "$port" "$engine" "$threads" "$test_type"
                    sleep 5  # 短暂休息
                done
                
                cleanup_test_data "$db_type" "$port" "$test_type"
            done
        done
        
        collect_system_info "$db_type"
    done
    
    # 停止容器
    stop_containers
    
    # 生成报告
    generate_enhanced_report
    
    log "综合性能测试完成！报告保存在: $CURRENT_REPORT_DIR"
    log_info "主要报告文件: $CURRENT_REPORT_DIR/comprehensive_performance_report.md"
}

# 帮助信息
show_help() {
    cat << EOF
MySQL vs Percona vs MariaDB 综合性能测试脚本

用法: $0 [选项]

选项:
  -h, --help              显示此帮助信息
  --mysql-version         MySQL版本 (默认: 8.0)
  --percona-version       Percona版本 (默认: 8.0)
  --mariadb-version       MariaDB版本 (默认: latest)
  --test-duration         测试持续时间(秒) (默认: 300)
  --table-size            测试表大小 (默认: 100000)
  --threads               线程数列表 (默认: "1 4 8 16 32 64")
  --report-dir            报告目录 (默认: ./performance_reports)

支持的存储引擎:
  - MySQL: InnoDB
  - Percona: InnoDB, RocksDB
  - MariaDB: InnoDB, ColumnStore

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
        --mariadb-version)
            MARIADB_VERSION="$2"
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