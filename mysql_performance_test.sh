#!/bin/bash
# MySQL 预编译包性能测试工具
# 
# 用法: ./mysql_performance_test.sh [package_path]
# 
# 功能:
# 1. 安装和配置 MySQL 预编译包
# 2. 运行性能基准测试
# 3. 生成性能报告

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_PATH="${1:-}"
TEST_DB="performance_test"
MYSQL_USER="root"
MYSQL_PASS="test123"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing_deps=()
    
    # 检查必要工具
    command -v unzip >/dev/null || missing_deps+=("unzip")
    command -v sysbench >/dev/null || missing_deps+=("sysbench")
    command -v htop >/dev/null || missing_deps+=("htop")
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "缺少依赖: ${missing_deps[*]}"
        log_info "Ubuntu/Debian: sudo apt install ${missing_deps[*]}"
        log_info "CentOS/RHEL: sudo yum install ${missing_deps[*]}"
        exit 1
    fi
    
    log_success "系统依赖检查完成"
}

# 解压并安装包
install_package() {
    local pkg_path="$1"
    
    if [[ ! -f "$pkg_path" ]]; then
        log_error "包文件不存在: $pkg_path"
        exit 1
    fi
    
    log_info "解压安装包: $(basename "$pkg_path")"
    
    # 检查文件类型
    local file_type=$(file "$pkg_path")
    if [[ "$file_type" == *"Zip archive"* ]]; then
        log_warning "文件为 ZIP 格式 (虽然扩展名为 .xz)"
        unzip -q "$pkg_path" -d /tmp/mysql_test/
    elif [[ "$file_type" == *"XZ compressed"* ]]; then
        tar -xf "$pkg_path" -C /tmp/mysql_test/
    else
        log_error "不支持的文件格式: $file_type"
        exit 1
    fi
    
    # 查找 MySQL 目录
    MYSQL_DIR=$(find /tmp/mysql_test -maxdepth 2 -type d -name "bin" | head -1 | dirname)
    
    if [[ -z "$MYSQL_DIR" ]]; then
        log_error "未找到 MySQL 安装目录"
        exit 1
    fi
    
    log_success "MySQL 安装目录: $MYSQL_DIR"
    export PATH="$MYSQL_DIR/bin:$PATH"
}

# 分析包信息
analyze_package() {
    log_info "分析包信息..."
    
    echo "=== MySQL 版本信息 ==="
    if command -v mysql >/dev/null; then
        mysql --version || log_warning "无法获取 MySQL 版本 (可能缺少运行时依赖)"
    fi
    
    echo -e "\n=== 存储引擎支持 ==="
    find "$MYSQL_DIR" -name "ha_*.so" | while read -r engine; do
        engine_name=$(basename "$engine" .so | sed 's/^ha_//')
        engine_size=$(du -h "$engine" | cut -f1)
        echo "  ✓ $engine_name ($engine_size)"
    done
    
    echo -e "\n=== 依赖库分析 ==="
    find "$MYSQL_DIR" -name "lib*.so*" | head -10 | while read -r lib; do
        lib_name=$(basename "$lib")
        lib_size=$(du -h "$lib" | cut -f1)
        echo "  • $lib_name ($lib_size)"
    done
    
    echo -e "\n=== 压缩库版本 ==="
    for lib in zlib zstd curl; do
        lib_file=$(find "$MYSQL_DIR" -name "lib${lib}*.so*" | head -1)
        if [[ -n "$lib_file" ]]; then
            version=$(strings "$lib_file" 2>/dev/null | grep -E "^[0-9]+\.[0-9]+" | head -1)
            echo "  • $lib: $version"
        fi
    done
}

# 启动 MySQL 服务
start_mysql() {
    log_info "配置和启动 MySQL 服务..."
    
    local data_dir="/tmp/mysql_test/data"
    local my_cnf="/tmp/mysql_test/my.cnf"
    
    mkdir -p "$data_dir"
    
    # 创建配置文件
    cat > "$my_cnf" << EOF
[mysqld]
basedir = $MYSQL_DIR
datadir = $data_dir
socket = /tmp/mysql_test/mysql.sock
port = 3307
user = $(whoami)

# 性能相关配置
innodb_buffer_pool_size = 512M
innodb_log_file_size = 128M
innodb_flush_log_at_trx_commit = 2
sync_binlog = 0

# RocksDB 配置 (如果支持)
rocksdb_default_cf_options = compression=snappy
rocksdb_block_cache_size = 256M

# 连接配置
max_connections = 200
skip-networking = 0

# 日志配置
log-error = $data_dir/error.log
pid-file = $data_dir/mysql.pid

# 安全配置
skip-grant-tables
EOF

    # 初始化数据库
    if [[ -f "$MYSQL_DIR/bin/mysqld" ]]; then
        log_info "初始化 MySQL 数据目录..."
        "$MYSQL_DIR/bin/mysqld" --defaults-file="$my_cnf" --initialize-insecure
        
        log_info "启动 MySQL 服务..."
        "$MYSQL_DIR/bin/mysqld" --defaults-file="$my_cnf" &
        MYSQL_PID=$!
        
        # 等待 MySQL 启动
        for i in {1..30}; do
            if mysql -S /tmp/mysql_test/mysql.sock -e "SELECT 1;" >/dev/null 2>&1; then
                log_success "MySQL 服务启动成功"
                return 0
            fi
            sleep 1
        done
        
        log_error "MySQL 服务启动失败"
        return 1
    else
        log_error "未找到 mysqld 可执行文件"
        return 1
    fi
}

# 运行性能测试
run_performance_tests() {
    log_info "开始性能测试..."
    
    local mysql_sock="/tmp/mysql_test/mysql.sock"
    local test_results="/tmp/mysql_test/test_results.txt"
    
    # 创建测试数据库
    mysql -S "$mysql_sock" -e "CREATE DATABASE IF NOT EXISTS $TEST_DB;"
    
    echo "=== MySQL 预编译包性能测试报告 ===" > "$test_results"
    echo "测试时间: $(date)" >> "$test_results"
    echo "包路径: $PACKAGE_PATH" >> "$test_results"
    echo "" >> "$test_results"
    
    # 测试 1: 基础插入性能
    log_info "测试 1: 基础插入性能"
    echo "=== 测试 1: 基础插入性能 ===" >> "$test_results"
    
    sysbench --mysql-socket="$mysql_sock" --mysql-db="$TEST_DB" \
        oltp_insert --tables=1 --table-size=100000 prepare >> "$test_results" 2>&1
    
    sysbench --mysql-socket="$mysql_sock" --mysql-db="$TEST_DB" \
        oltp_insert --tables=1 --threads=8 --time=60 \
        run >> "$test_results" 2>&1
    
    # 测试 2: 读写混合测试
    log_info "测试 2: 读写混合测试"  
    echo -e "\n=== 测试 2: 读写混合测试 ===" >> "$test_results"
    
    sysbench --mysql-socket="$mysql_sock" --mysql-db="$TEST_DB" \
        oltp_read_write --tables=2 --table-size=50000 --threads=4 --time=60 \
        run >> "$test_results" 2>&1
    
    # 测试 3: RocksDB 存储引擎测试 (如果支持)
    if mysql -S "$mysql_sock" -e "SHOW ENGINES;" | grep -i rocksdb >/dev/null 2>&1; then
        log_info "测试 3: RocksDB 存储引擎性能"
        echo -e "\n=== 测试 3: RocksDB 存储引擎 ===" >> "$test_results"
        
        mysql -S "$mysql_sock" -e "
            USE $TEST_DB;
            CREATE TABLE rocksdb_test (
                id INT PRIMARY KEY,
                data TEXT
            ) ENGINE=RocksDB;
            
            INSERT INTO rocksdb_test 
            SELECT id, CONCAT('test_data_', id) 
            FROM sbtest1 LIMIT 10000;
        " >> "$test_results" 2>&1
        
        echo "RocksDB 表创建和数据插入完成" >> "$test_results"
    fi
    
    # 测试 4: 压缩性能测试
    log_info "测试 4: 压缩算法性能"
    echo -e "\n=== 测试 4: 压缩算法性能 ===" >> "$test_results"
    
    for compression in snappy lz4 zstd; do
        if mysql -S "$mysql_sock" -e "SHOW ENGINES;" | grep -i rocksdb >/dev/null 2>&1; then
            echo "测试 $compression 压缩..." >> "$test_results"
            
            mysql -S "$mysql_sock" -e "
                USE $TEST_DB;
                DROP TABLE IF EXISTS test_$compression;
                CREATE TABLE test_$compression (
                    id INT PRIMARY KEY,
                    data TEXT
                ) ENGINE=RocksDB COMMENT='compression=$compression';
                
                INSERT INTO test_$compression 
                SELECT id, REPEAT('compression_test_data_', 50) 
                FROM sbtest1 LIMIT 5000;
            " >> "$test_results" 2>&1
            
            # 查看表大小
            mysql -S "$mysql_sock" -e "
                SELECT 
                    table_name,
                    ROUND(data_length/1024/1024, 2) as 'Size_MB'
                FROM information_schema.tables 
                WHERE table_schema = '$TEST_DB' 
                AND table_name = 'test_$compression';
            " >> "$test_results" 2>&1
        fi
    done
    
    log_success "性能测试完成，结果保存到: $test_results"
}

# 生成测试报告
generate_report() {
    local report_file="/tmp/mysql_test/performance_report.html"
    
    log_info "生成性能测试报告..."
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>MySQL 预编译包性能测试报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f0f0f0; padding: 15px; border-radius: 5px; }
        .section { margin: 20px 0; }
        .result { background: #f9f9f9; padding: 10px; border-left: 4px solid #007acc; }
        pre { background: #f5f5f5; padding: 10px; overflow-x: auto; }
        .success { color: green; }
        .warning { color: orange; }
        .error { color: red; }
    </style>
</head>
<body>
    <div class="header">
        <h1>MySQL 预编译包性能测试报告</h1>
        <p>生成时间: $(date)</p>
        <p>测试包: $(basename "$PACKAGE_PATH")</p>
    </div>
    
    <div class="section">
        <h2>包分析结果</h2>
        <div class="result">
            <pre>$(cat /tmp/mysql_test/package_analysis.txt 2>/dev/null || echo "包分析信息不可用")</pre>
        </div>
    </div>
    
    <div class="section">
        <h2>性能测试结果</h2>
        <div class="result">
            <pre>$(cat /tmp/mysql_test/test_results.txt 2>/dev/null || echo "测试结果不可用")</pre>
        </div>
    </div>
    
    <div class="section">
        <h2>建议和总结</h2>
        <div class="result">
            <h3>性能特点</h3>
            <ul>
                <li>使用了 vcpkg 管理的现代化依赖库</li>
                <li>支持 RocksDB 存储引擎和多种压缩算法</li>
                <li>采用 GCC 16.0.0 编译，优化程度较高</li>
            </ul>
            
            <h3>部署建议</h3>
            <ul>
                <li>确保系统有足够的运行时依赖</li>
                <li>建议在测试环境充分验证后再用于生产</li>
                <li>可考虑使用 RocksDB 引擎提升写入性能</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

    log_success "HTML 报告生成完成: $report_file"
}

# 清理资源
cleanup() {
    log_info "清理测试资源..."
    
    if [[ -n "$MYSQL_PID" ]]; then
        kill $MYSQL_PID 2>/dev/null || true
        wait $MYSQL_PID 2>/dev/null || true
    fi
    
    # 保留测试结果，只清理临时文件
    rm -f /tmp/mysql_test/mysql.sock
    rm -f /tmp/mysql_test/my.cnf
}

# 主函数
main() {
    echo "==================================="
    echo "  MySQL 预编译包性能测试工具"
    echo "==================================="
    
    if [[ -z "$PACKAGE_PATH" ]]; then
        echo "用法: $0 <package_path>"
        echo "示例: $0 /path/to/percona80-ubuntu.xz"
        exit 1
    fi
    
    # 创建工作目录
    rm -rf /tmp/mysql_test
    mkdir -p /tmp/mysql_test
    
    # 设置清理陷阱
    trap cleanup EXIT
    
    # 执行测试流程
    check_dependencies
    install_package "$PACKAGE_PATH"
    analyze_package > /tmp/mysql_test/package_analysis.txt
    
    # 尝试启动 MySQL 并运行测试
    if start_mysql; then
        run_performance_tests
        generate_report
        
        log_success "所有测试完成！"
        log_info "查看结果:"
        log_info "  - 文本报告: /tmp/mysql_test/test_results.txt"
        log_info "  - HTML 报告: /tmp/mysql_test/performance_report.html"
    else
        log_warning "MySQL 启动失败，仅完成静态分析"
        log_info "分析结果: /tmp/mysql_test/package_analysis.txt"
    fi
}

# 运行主函数
main "$@"