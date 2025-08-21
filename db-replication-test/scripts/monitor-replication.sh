#!/bin/bash

# 监控主从同步状态的脚本

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 配置
PERCONA_PORT=${PERCONA_PORT:-3306}
MARIADB_PORT=${MARIADB_PORT:-3307}
MONITOR_INTERVAL=${MONITOR_INTERVAL:-5}
MAX_LAG_SECONDS=${MAX_LAG_SECONDS:-10}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# 检查 Percona 从库状态
check_percona_slave_status() {
    local mysql_cmd="$SCRIPT_DIR/../percona/mysql/bin/mysql -h127.0.0.1 -P$PERCONA_PORT -uroot"
    
    local slave_status
    slave_status=$($mysql_cmd -e "SHOW SLAVE STATUS\\G" 2>/dev/null || echo "")
    
    if [[ -z "$slave_status" ]]; then
        echo "Percona 从库未配置主从复制"
        return 1
    fi
    
    local io_running=$(echo "$slave_status" | grep "Slave_IO_Running:" | awk '{print $2}')
    local sql_running=$(echo "$slave_status" | grep "Slave_SQL_Running:" | awk '{print $2}')
    local seconds_behind_master=$(echo "$slave_status" | grep "Seconds_Behind_Master:" | awk '{print $2}')
    local last_error=$(echo "$slave_status" | grep "Last_Error:" | cut -d':' -f2- | xargs)
    
    echo "Percona 从库状态:"
    echo "  IO线程: $io_running"
    echo "  SQL线程: $sql_running"
    echo "  延迟: ${seconds_behind_master}秒"
    
    if [[ -n "$last_error" && "$last_error" != "none" ]]; then
        echo "  错误: $last_error"
    fi
    
    if [[ "$io_running" != "Yes" || "$sql_running" != "Yes" ]]; then
        log "警告: Percona 从库复制线程异常"
        return 1
    fi
    
    if [[ "$seconds_behind_master" != "NULL" && "$seconds_behind_master" -gt "$MAX_LAG_SECONDS" ]]; then
        log "警告: Percona 从库延迟过大: ${seconds_behind_master}秒"
        return 1
    fi
    
    return 0
}

# 检查 MariaDB 从库状态
check_mariadb_slave_status() {
    local mysql_cmd="mysql -h127.0.0.1 -P$MARIADB_PORT -uroot -proot"
    
    local slave_status
    slave_status=$($mysql_cmd -e "SHOW SLAVE STATUS\\G" 2>/dev/null || echo "")
    
    if [[ -z "$slave_status" ]]; then
        echo "MariaDB 从库未配置主从复制"
        return 1
    fi
    
    local io_running=$(echo "$slave_status" | grep "Slave_IO_Running:" | awk '{print $2}')
    local sql_running=$(echo "$slave_status" | grep "Slave_SQL_Running:" | awk '{print $2}')
    local seconds_behind_master=$(echo "$slave_status" | grep "Seconds_Behind_Master:" | awk '{print $2}')
    local last_error=$(echo "$slave_status" | grep "Last_Error:" | cut -d':' -f2- | xargs)
    
    echo "MariaDB 从库状态:"
    echo "  IO线程: $io_running"
    echo "  SQL线程: $sql_running"
    echo "  延迟: ${seconds_behind_master}秒"
    
    if [[ -n "$last_error" && "$last_error" != "none" ]]; then
        echo "  错误: $last_error"
    fi
    
    if [[ "$io_running" != "Yes" || "$sql_running" != "Yes" ]]; then
        log "警告: MariaDB 从库复制线程异常"
        return 1
    fi
    
    if [[ "$seconds_behind_master" != "NULL" && "$seconds_behind_master" -gt "$MAX_LAG_SECONDS" ]]; then
        log "警告: MariaDB 从库延迟过大: ${seconds_behind_master}秒"
        return 1
    fi
    
    return 0
}

# 监控主库状态
check_master_status() {
    local db_type="$1"
    local port="$2"
    
    if [[ "$db_type" == "percona" ]]; then
        local mysql_cmd="$SCRIPT_DIR/../percona/mysql/bin/mysql -h127.0.0.1 -P$port -uroot"
    else
        local mysql_cmd="mysql -h127.0.0.1 -P$port -uroot -proot"
    fi
    
    local master_status
    master_status=$($mysql_cmd -e "SHOW MASTER STATUS\\G" 2>/dev/null || echo "")
    
    if [[ -z "$master_status" ]]; then
        echo "$db_type 主库未启用二进制日志"
        return 1
    fi
    
    local log_file=$(echo "$master_status" | grep "File:" | awk '{print $2}')
    local log_position=$(echo "$master_status" | grep "Position:" | awk '{print $2}')
    
    echo "$db_type 主库状态:"
    echo "  日志文件: $log_file"
    echo "  日志位置: $log_position"
    
    return 0
}

# 持续监控模式
continuous_monitor() {
    log "开始持续监控主从同步状态..."
    log "监控间隔: ${MONITOR_INTERVAL}秒"
    log "最大延迟阈值: ${MAX_LAG_SECONDS}秒"
    
    while true; do
        echo "----------------------------------------"
        echo "时间: $(date)"
        
        # 检查是否有进程在运行
        if pgrep -f "mysqld.*3306" >/dev/null; then
            check_master_status "percona" "$PERCONA_PORT" || true
            check_percona_slave_status || true
        fi
        
        if docker ps --filter "name=mariadb" --format "table {{.Names}}" | grep -q mariadb; then
            check_master_status "mariadb" "$MARIADB_PORT" || true
            check_mariadb_slave_status || true
        fi
        
        echo ""
        sleep "$MONITOR_INTERVAL"
    done
}

# 一次性检查模式
single_check() {
    echo "主从同步状态检查 - $(date)"
    echo "========================================"
    
    local has_error=false
    
    # 检查 Percona
    if pgrep -f "mysqld.*3306" >/dev/null; then
        if ! check_master_status "percona" "$PERCONA_PORT"; then
            has_error=true
        fi
        if ! check_percona_slave_status; then
            has_error=true
        fi
    else
        echo "Percona Server 未运行"
    fi
    
    echo ""
    
    # 检查 MariaDB
    if docker ps --filter "name=mariadb" --format "table {{.Names}}" | grep -q mariadb; then
        if ! check_master_status "mariadb" "$MARIADB_PORT"; then
            has_error=true
        fi
        if ! check_mariadb_slave_status; then
            has_error=true
        fi
    else
        echo "MariaDB 未运行"
    fi
    
    if [[ "$has_error" == "true" ]]; then
        return 1
    else
        log "所有主从复制状态正常"
        return 0
    fi
}

# 主函数
main() {
    case "${1:-single}" in
        "monitor"|"continuous")
            continuous_monitor
            ;;
        "single"|"check")
            single_check
            ;;
        "help"|"--help")
            cat << EOF
主从同步监控脚本

用法:
    $0 [模式]

模式:
    single      一次性检查 (默认)
    monitor     持续监控模式
    help        显示帮助

环境变量:
    PERCONA_PORT        Percona 端口 (默认: 3306)
    MARIADB_PORT        MariaDB 端口 (默认: 3307)
    MONITOR_INTERVAL    监控间隔秒数 (默认: 5)
    MAX_LAG_SECONDS     最大延迟阈值 (默认: 10)

EOF
            ;;
        *)
            echo "未知模式: $1"
            echo "使用 '$0 help' 查看帮助"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi