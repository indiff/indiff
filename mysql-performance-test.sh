#!/bin/bash
# MySQL性能测试框架 - 主脚本
# 测试Facebook MySQL, MariaDB, Oracle MySQL, Percona Server的性能对比
# 支持不同存储引擎：InnoDB, MyISAM, RocksDB

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORK_DIR="/tmp/mysql-performance-test"
RESULTS_DIR="$SCRIPT_DIR/performance-results"
LOG_DIR="$RESULTS_DIR/logs"

# 数据库下载URLs（来自GitHub Release）
RELEASE_TAG="20250923_2104_mysql"
BASE_URL="https://github.com/indiff/indiff/releases/download/$RELEASE_TAG"

declare -A DB_URLS=(
    ["fbmysql-centos7"]="$BASE_URL/fbmysql-centos7-x86_64-20250923_2101.xz"
    ["mariadb-centos7"]="$BASE_URL/mariadb-centos7-x86_64-20250923_1714.xz"
    ["omysql-centos7"]="$BASE_URL/omysql-centos7-x86_64-20250923_2054.xz"
    ["percona80-centos7"]="$BASE_URL/percona80-centos7-x86_64-20250923_1839.xz"
    ["percona80-ubuntu"]="$BASE_URL/percona80-ubuntu-x86_64-20250923_0821.xz"
)

declare -A DB_NAMES=(
    ["fbmysql-centos7"]="Facebook MySQL 5.6"
    ["mariadb-centos7"]="MariaDB 10.x"
    ["omysql-centos7"]="Oracle MySQL 8.0"
    ["percona80-centos7"]="Percona Server 8.0"
    ["percona80-ubuntu"]="Percona Server 8.0 (Ubuntu)"
)

# 存储引擎列表
STORAGE_ENGINES=("InnoDB" "MyISAM" "RocksDB")

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_DIR/main.log"
}

error() {
    echo "[ERROR] $*" >&2 | tee -a "$LOG_DIR/main.log"
    exit 1
}

# 初始化环境
init_environment() {
    log "初始化测试环境..."
    
    # 创建工作目录
    mkdir -p "$WORK_DIR" "$RESULTS_DIR" "$LOG_DIR"
    
    # 检查必要的工具
    local required_tools=("curl" "unzip" "sysbench" "mysql")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "缺少必要工具: $tool"
        fi
    done
    
    log "环境初始化完成"
}

# 下载数据库
download_database() {
    local db_key="$1"
    local url="${DB_URLS[$db_key]}"
    local filename=$(basename "$url")
    local download_path="$WORK_DIR/$filename"
    
    log "开始下载 ${DB_NAMES[$db_key]}..."
    
    if [[ -f "$download_path" ]]; then
        log "文件已存在，跳过下载: $filename"
        return 0
    fi
    
    # 使用ghproxy加速下载
    local proxy_url="https://ghproxy.cfd/$url"
    
    if curl -L --progress-bar -o "$download_path" "$proxy_url"; then
        log "下载完成: $filename"
    else
        log "代理下载失败，尝试直接下载..."
        if curl -L --progress-bar -o "$download_path" "$url"; then
            log "直接下载完成: $filename"
        else
            error "下载失败: $filename"
        fi
    fi
}

# 解压并安装数据库
install_database() {
    local db_key="$1"
    local filename=$(basename "${DB_URLS[$db_key]}")
    local download_path="$WORK_DIR/$filename"
    local install_dir="$WORK_DIR/$db_key"
    
    log "安装 ${DB_NAMES[$db_key]}..."
    
    if [[ -d "$install_dir" ]]; then
        log "数据库已安装，跳过: $db_key"
        return 0
    fi
    
    mkdir -p "$install_dir"
    
    # 解压文件（注意：.xz文件实际是zip格式）
    if file "$download_path" | grep -q "Zip archive"; then
        unzip -q "$download_path" -d "$install_dir"
    else
        # 如果真的是xz格式
        tar -xf "$download_path" -C "$install_dir"
    fi
    
    log "安装完成: ${DB_NAMES[$db_key]}"
}

# 启动数据库服务
start_database() {
    local db_key="$1"
    local install_dir="$WORK_DIR/$db_key"
    local data_dir="$install_dir/data"
    local port="$2"
    
    log "启动 ${DB_NAMES[$db_key]} (端口: $port)..."
    
    # 创建数据目录
    mkdir -p "$data_dir"
    
    # 初始化数据库（如果需要）
    if [[ ! -f "$data_dir/mysql/user.frm" ]] && [[ ! -f "$data_dir/mysql/user.MYD" ]]; then
        log "初始化数据库..."
        if [[ -f "$install_dir/bin/mysqld" ]]; then
            "$install_dir/bin/mysqld" --initialize-insecure --basedir="$install_dir" --datadir="$data_dir" --user=$(whoami) || true
        fi
    fi
    
    # 启动MySQL服务
    local pid_file="$data_dir/mysql.pid"
    local socket_file="$data_dir/mysql.sock"
    local log_file="$LOG_DIR/${db_key}_mysql.log"
    
    if [[ -f "$install_dir/bin/mysqld_safe" ]]; then
        "$install_dir/bin/mysqld_safe" \
            --basedir="$install_dir" \
            --datadir="$data_dir" \
            --port="$port" \
            --socket="$socket_file" \
            --pid-file="$pid_file" \
            --log-error="$log_file" \
            --user=$(whoami) &
    elif [[ -f "$install_dir/bin/mysqld" ]]; then
        "$install_dir/bin/mysqld" \
            --basedir="$install_dir" \
            --datadir="$data_dir" \
            --port="$port" \
            --socket="$socket_file" \
            --pid-file="$pid_file" \
            --log-error="$log_file" \
            --user=$(whoami) &
    else
        error "找不到mysqld可执行文件: $install_dir"
    fi
    
    # 等待服务启动
    local max_wait=30
    local count=0
    while [[ $count -lt $max_wait ]]; do
        if [[ -S "$socket_file" ]]; then
            log "${DB_NAMES[$db_key]} 启动成功"
            return 0
        fi
        sleep 2
        ((count+=2))
    done
    
    error "${DB_NAMES[$db_key]} 启动失败"
}

# 停止数据库服务
stop_database() {
    local db_key="$1"
    local install_dir="$WORK_DIR/$db_key"
    local data_dir="$install_dir/data"
    local pid_file="$data_dir/mysql.pid"
    
    log "停止 ${DB_NAMES[$db_key]}..."
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            sleep 5
            # 强制杀死如果还在运行
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid"
            fi
        fi
        rm -f "$pid_file"
    fi
    
    log "${DB_NAMES[$db_key]} 已停止"
}

# 主函数
main() {
    local action="${1:-help}"
    
    case "$action" in
        "init")
            init_environment
            ;;
        "download")
            init_environment
            for db_key in "${!DB_URLS[@]}"; do
                download_database "$db_key"
            done
            ;;
        "install")
            init_environment
            for db_key in "${!DB_URLS[@]}"; do
                download_database "$db_key"
                install_database "$db_key"
            done
            ;;
        "test")
            # 运行性能测试
            bash "$SCRIPT_DIR/performance-tests/run-benchmark.sh"
            ;;
        "report")
            # 生成测试报告
            bash "$SCRIPT_DIR/performance-tests/generate-report.sh"
            ;;
        "clean")
            log "清理测试环境..."
            rm -rf "$WORK_DIR"
            log "清理完成"
            ;;
        *)
            echo "MySQL性能测试框架"
            echo ""
            echo "用法: $0 <命令>"
            echo ""
            echo "命令:"
            echo "  init     - 初始化测试环境"
            echo "  download - 下载所有数据库"
            echo "  install  - 下载并安装所有数据库"
            echo "  test     - 运行性能测试"
            echo "  report   - 生成测试报告"
            echo "  clean    - 清理测试环境"
            echo ""
            echo "支持的数据库版本:"
            for db_key in "${!DB_NAMES[@]}"; do
                echo "  - ${DB_NAMES[$db_key]}"
            done
            ;;
    esac
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi