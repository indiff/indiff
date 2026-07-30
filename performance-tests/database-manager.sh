#!/bin/bash
# 数据库管理脚本 - 用于启动、停止、监控数据库实例

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR="/tmp/mysql-performance-test"

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

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

# 启动单个数据库
start_database() {
    local db_key="$1"
    local install_dir="$WORK_DIR/$db_key"
    local data_dir="$install_dir/data"
    local port="${DB_PORTS[$db_key]}"
    
    log "启动 ${DB_NAMES[$db_key]} (端口: $port)..."
    
    if [[ ! -d "$install_dir" ]]; then
        error "数据库未安装: $db_key"
    fi
    
    # 创建数据目录
    mkdir -p "$data_dir"
    
    # 检查是否已经在运行
    local pid_file="$data_dir/mysql.pid"
    if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
        log "${DB_NAMES[$db_key]} 已经在运行"
        return 0
    fi
    
    # 初始化数据库（如果需要）
    if [[ ! -d "$data_dir/mysql" ]]; then
        log "初始化数据库..."
        
        # 尝试不同的初始化方法
        if [[ -f "$install_dir/bin/mysqld" ]]; then
            "$install_dir/bin/mysqld" \
                --initialize-insecure \
                --basedir="$install_dir" \
                --datadir="$data_dir" \
                --user=$(whoami) || {
                log "尝试使用mysql_install_db..."
                if [[ -f "$install_dir/bin/mysql_install_db" ]]; then
                    "$install_dir/bin/mysql_install_db" \
                        --basedir="$install_dir" \
                        --datadir="$data_dir" \
                        --user=$(whoami) || log "初始化失败，继续尝试启动..."
                fi
            }
        fi
    fi
    
    # 创建配置文件
    local my_cnf="$data_dir/my.cnf"
    cat > "$my_cnf" << EOF
[mysqld]
basedir=$install_dir
datadir=$data_dir
socket=$data_dir/mysql.sock
pid-file=$data_dir/mysql.pid
port=$port
bind-address=127.0.0.1
user=$(whoami)

# 基本配置
sql_mode=NO_ENGINE_SUBSTITUTION
default-storage-engine=InnoDB
max_connections=1000
max_allowed_packet=16M
thread_cache_size=128
sort_buffer_size=4M
bulk_insert_buffer_size=64M
myisam_sort_buffer_size=128M
myisam_max_sort_file_size=10G
myisam_repair_threads=1

# InnoDB配置
innodb_buffer_pool_size=512M
innodb_log_file_size=128M
innodb_log_buffer_size=32M
innodb_flush_log_at_trx_commit=2
innodb_lock_wait_timeout=120
innodb_io_capacity=1000

# RocksDB配置 (如果支持)
rocksdb_default_cf_options=write_buffer_size=128m;max_write_buffer_number=4;min_write_buffer_number_to_merge=2;compression=kLZ4Compression
rocksdb_block_cache_size=512M
rocksdb_write_buffer_size=128M

# 慢查询日志
slow_query_log=1
slow_query_log_file=$data_dir/slow.log
long_query_time=2

# 错误日志
log-error=$data_dir/error.log

# 禁用DNS解析
skip-name-resolve

[client]
socket=$data_dir/mysql.sock
port=$port
EOF
    
    # 启动MySQL服务
    local log_file="$data_dir/startup.log"
    
    if [[ -f "$install_dir/bin/mysqld_safe" ]]; then
        nohup "$install_dir/bin/mysqld_safe" \
            --defaults-file="$my_cnf" \
            --user=$(whoami) \
            > "$log_file" 2>&1 &
    elif [[ -f "$install_dir/bin/mysqld" ]]; then
        nohup "$install_dir/bin/mysqld" \
            --defaults-file="$my_cnf" \
            --user=$(whoami) \
            > "$log_file" 2>&1 &
    else
        error "找不到mysqld可执行文件: $install_dir"
    fi
    
    # 等待服务启动
    local socket_file="$data_dir/mysql.sock"
    local max_wait=60
    local count=0
    
    while [[ $count -lt $max_wait ]]; do
        if [[ -S "$socket_file" ]] && mysql -S"$socket_file" -uroot -e "SELECT 1;" &>/dev/null; then
            log "${DB_NAMES[$db_key]} 启动成功"
            
            # 设置root密码（如果需要）
            mysql -S"$socket_file" -uroot -e "
                ALTER USER 'root'@'localhost' IDENTIFIED BY '';
                FLUSH PRIVILEGES;
            " 2>/dev/null || true
            
            return 0
        fi
        sleep 2
        ((count+=2))
        log "等待 ${DB_NAMES[$db_key]} 启动... ($count/$max_wait)"
    done
    
    log "启动超时，检查日志: $log_file"
    tail -20 "$log_file" 2>/dev/null || true
    error "${DB_NAMES[$db_key]} 启动失败"
}

# 停止单个数据库
stop_database() {
    local db_key="$1"
    local install_dir="$WORK_DIR/$db_key"
    local data_dir="$install_dir/data"
    local pid_file="$data_dir/mysql.pid"
    local socket_file="$data_dir/mysql.sock"
    
    log "停止 ${DB_NAMES[$db_key]}..."
    
    # 尝试优雅关闭
    if [[ -S "$socket_file" ]]; then
        mysql -S"$socket_file" -uroot -e "SHUTDOWN;" 2>/dev/null && {
            sleep 5
            log "${DB_NAMES[$db_key]} 优雅关闭完成"
            return 0
        }
    fi
    
    # 使用PID文件关闭
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log "发送TERM信号到进程: $pid"
            kill "$pid"
            
            # 等待进程结束
            local count=0
            while [[ $count -lt 30 ]] && kill -0 "$pid" 2>/dev/null; do
                sleep 1
                ((count++))
            done
            
            # 强制杀死如果还在运行
            if kill -0 "$pid" 2>/dev/null; then
                log "强制杀死进程: $pid"
                kill -9 "$pid"
            fi
        fi
        rm -f "$pid_file"
    fi
    
    # 清理socket文件
    rm -f "$socket_file"
    
    log "${DB_NAMES[$db_key]} 已停止"
}

# 检查数据库状态
check_database_status() {
    local db_key="$1"
    local install_dir="$WORK_DIR/$db_key"
    local data_dir="$install_dir/data"
    local pid_file="$data_dir/mysql.pid"
    local socket_file="$data_dir/mysql.sock"
    local port="${DB_PORTS[$db_key]}"
    
    printf "%-25s " "${DB_NAMES[$db_key]}:"
    
    # 检查进程是否存在
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            # 检查是否能连接
            if mysql -h127.0.0.1 -P"$port" -uroot -e "SELECT 1;" &>/dev/null; then
                echo "运行中 (PID: $pid, 端口: $port) ✓"
            elif [[ -S "$socket_file" ]] && mysql -S"$socket_file" -uroot -e "SELECT 1;" &>/dev/null; then
                echo "运行中 (PID: $pid, Socket) ✓"
            else
                echo "进程存在但无法连接 (PID: $pid) ⚠"
            fi
        else
            echo "已停止 (PID文件存在但进程不存在) ✗"
        fi
    else
        echo "已停止 ✗"
    fi
}

# 显示数据库连接信息
show_connection_info() {
    local db_key="$1"
    local data_dir="$WORK_DIR/$db_key/data"
    local socket_file="$data_dir/mysql.sock"
    local port="${DB_PORTS[$db_key]}"
    
    echo "=== ${DB_NAMES[$db_key]} 连接信息 ==="
    echo "TCP连接: mysql -h127.0.0.1 -P$port -uroot"
    echo "Socket连接: mysql -S$socket_file -uroot"
    echo "数据目录: $data_dir"
    echo ""
}

# 监控数据库性能
monitor_database() {
    local db_key="$1"
    local duration="${2:-60}"
    local data_dir="$WORK_DIR/$db_key/data"
    local socket_file="$data_dir/mysql.sock"
    local port="${DB_PORTS[$db_key]}"
    
    log "监控 ${DB_NAMES[$db_key]} 性能 (时长: ${duration}秒)..."
    
    # 确定连接方式
    local mysql_cmd="mysql -h127.0.0.1 -P$port -uroot"
    if ! $mysql_cmd -e "SELECT 1;" &>/dev/null; then
        if [[ -S "$socket_file" ]]; then
            mysql_cmd="mysql -S$socket_file -uroot"
        else
            error "无法连接到 ${DB_NAMES[$db_key]}"
        fi
    fi
    
    echo "时间,QPS,TPS,连接数,缓存命中率"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + duration))
    
    while [[ $(date +%s) -lt $end_time ]]; do
        local current_time=$(date '+%H:%M:%S')
        
        # 获取状态变量
        local status_output=$($mysql_cmd -e "SHOW GLOBAL STATUS LIKE 'Questions'; SHOW GLOBAL STATUS LIKE 'Com_commit'; SHOW GLOBAL STATUS LIKE 'Threads_connected'; SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read_requests'; SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_reads';" 2>/dev/null || echo "")
        
        if [[ -n "$status_output" ]]; then
            local questions=$(echo "$status_output" | grep "Questions" | awk '{print $2}')
            local commits=$(echo "$status_output" | grep "Com_commit" | awk '{print $2}')
            local connections=$(echo "$status_output" | grep "Threads_connected" | awk '{print $2}')
            local buffer_reads=$(echo "$status_output" | grep "Innodb_buffer_pool_read_requests" | awk '{print $2}')
            local disk_reads=$(echo "$status_output" | grep "Innodb_buffer_pool_reads" | awk '{print $2}')
            
            # 计算缓存命中率
            local hit_ratio=0
            if [[ -n "$buffer_reads" ]] && [[ -n "$disk_reads" ]] && [[ "$buffer_reads" -gt 0 ]]; then
                hit_ratio=$(echo "scale=2; (1 - $disk_reads / $buffer_reads) * 100" | bc -l 2>/dev/null || echo "0")
            fi
            
            echo "$current_time,${questions:-0},${commits:-0},${connections:-0},${hit_ratio}%"
        else
            echo "$current_time,N/A,N/A,N/A,N/A"
        fi
        
        sleep 5
    done
}

# 主函数
main() {
    local action="${1:-status}"
    local db_key="$2"
    
    case "$action" in
        "start")
            if [[ -n "$db_key" ]]; then
                start_database "$db_key"
            else
                for key in "${!DB_NAMES[@]}"; do
                    start_database "$key" || true
                done
            fi
            ;;
        "stop")
            if [[ -n "$db_key" ]]; then
                stop_database "$db_key"
            else
                for key in "${!DB_NAMES[@]}"; do
                    stop_database "$key" || true
                done
            fi
            ;;
        "restart")
            if [[ -n "$db_key" ]]; then
                stop_database "$db_key" || true
                sleep 2
                start_database "$db_key"
            else
                for key in "${!DB_NAMES[@]}"; do
                    stop_database "$key" || true
                done
                sleep 2
                for key in "${!DB_NAMES[@]}"; do
                    start_database "$key" || true
                done
            fi
            ;;
        "status")
            echo "MySQL数据库实例状态:"
            echo "==============================="
            for key in "${!DB_NAMES[@]}"; do
                check_database_status "$key"
            done
            ;;
        "info")
            if [[ -n "$db_key" ]]; then
                show_connection_info "$db_key"
            else
                for key in "${!DB_NAMES[@]}"; do
                    show_connection_info "$key"
                done
            fi
            ;;
        "monitor")
            if [[ -z "$db_key" ]]; then
                error "请指定要监控的数据库: $0 monitor <db_key> [duration]"
            fi
            local duration="${3:-60}"
            monitor_database "$db_key" "$duration"
            ;;
        *)
            echo "数据库管理脚本"
            echo ""
            echo "用法: $0 <命令> [数据库] [参数]"
            echo ""
            echo "命令:"
            echo "  start [db_key]   - 启动数据库(所有或指定)"
            echo "  stop [db_key]    - 停止数据库(所有或指定)"
            echo "  restart [db_key] - 重启数据库(所有或指定)"
            echo "  status           - 显示所有数据库状态"
            echo "  info [db_key]    - 显示连接信息"
            echo "  monitor <db_key> [duration] - 监控数据库性能"
            echo ""
            echo "支持的数据库 (db_key):"
            for key in "${!DB_NAMES[@]}"; do
                echo "  $key - ${DB_NAMES[$key]}"
            done
            ;;
    esac
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi