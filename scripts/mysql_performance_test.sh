#!/bin/bash

# MySQL性能测试脚本
# 用于测试三个MySQL版本的性能

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查依赖
check_dependencies() {
    log_info "检查依赖工具..."
    
    local missing_tools=()
    
    # 检查sysbench
    if ! command -v sysbench &> /dev/null; then
        missing_tools+=("sysbench")
    fi
    
    # 检查mysql客户端
    if ! command -v mysql &> /dev/null; then
        missing_tools+=("mysql-client")
    fi
    
    # 检查unzip
    if ! command -v unzip &> /dev/null; then
        missing_tools+=("unzip")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少以下工具: ${missing_tools[*]}"
        log_info "请安装缺少的工具后重新运行脚本"
        exit 1
    fi
    
    log_success "所有依赖工具检查通过"
}

# 下载MySQL版本
download_mysql_versions() {
    log_info "下载MySQL版本..."
    
    local base_url="https://github.com/indiff/indiff/releases/download/20250823_2217_mysql"
    local proxy_url="https://ghproxy.cfd/https://github.com/indiff/indiff/releases/download/20250823_2217_mysql"
    
    mkdir -p /tmp/mysql_test_downloads
    cd /tmp/mysql_test_downloads
    
    # 下载MariaDB
    log_info "下载MariaDB..."
    if ! curl -#Lo mariadb.zip "${proxy_url}/maria-centos7-x86_64-20250823_2037.xz"; then
        log_warning "代理下载失败，尝试直接下载..."
        curl -#Lo mariadb.zip "${base_url}/maria-centos7-x86_64-20250823_2037.xz"
    fi
    
    # 下载Percona Server 8.0 (CentOS)
    log_info "下载Percona Server 8.0 (CentOS)..."
    if ! curl -#Lo percona80-centos.zip "${proxy_url}/percona80-centos7-x86_64-20250823_2214.xz"; then
        log_warning "代理下载失败，尝试直接下载..."
        curl -#Lo percona80-centos.zip "${base_url}/percona80-centos7-x86_64-20250823_2214.xz"
    fi
    
    # 下载Percona Server 8.0 (Ubuntu)
    log_info "下载Percona Server 8.0 (Ubuntu)..."
    if ! curl -#Lo percona80-ubuntu.zip "${proxy_url}/percona80-ubuntu-x86_64-20250823_1143.xz"; then
        log_warning "代理下载失败，尝试直接下载..."
        curl -#Lo percona80-ubuntu.zip "${base_url}/percona80-ubuntu-x86_64-20250823_1143.xz"
    fi
    
    log_success "所有MySQL版本下载完成"
}

# 验证文件格式
verify_file_format() {
    log_info "验证下载文件格式..."
    
    cd /tmp/mysql_test_downloads
    
    for file in *.zip; do
        if [ -f "$file" ]; then
            file_type=$(file "$file")
            log_info "文件 $file 类型: $file_type"
            
            # 检查是否真的是ZIP格式
            if echo "$file_type" | grep -q "Zip archive"; then
                log_success "$file 确认为ZIP格式"
            elif echo "$file_type" | grep -q "XZ compressed"; then
                log_warning "$file 实际为XZ格式，重命名文件"
                mv "$file" "${file%.zip}.xz"
            else
                log_error "$file 文件格式未知: $file_type"
            fi
        fi
    done
}

# 解压文件
extract_files() {
    log_info "解压下载的文件..."
    
    cd /tmp/mysql_test_downloads
    
    # 解压MariaDB
    if [ -f "mariadb.zip" ]; then
        log_info "解压MariaDB..."
        unzip -q mariadb.zip -d mariadb/
    elif [ -f "mariadb.xz" ]; then
        log_info "解压MariaDB (XZ格式)..."
        mkdir -p mariadb
        xz -d mariadb.xz
        # 假设解压后是tar文件
        tar -xf mariadb -C mariadb/
    fi
    
    # 解压Percona CentOS
    if [ -f "percona80-centos.zip" ]; then
        log_info "解压Percona Server 8.0 (CentOS)..."
        unzip -q percona80-centos.zip -d percona80-centos/
    elif [ -f "percona80-centos.xz" ]; then
        log_info "解压Percona Server 8.0 (CentOS) (XZ格式)..."
        mkdir -p percona80-centos
        xz -d percona80-centos.xz
        tar -xf percona80-centos -C percona80-centos/
    fi
    
    # 解压Percona Ubuntu
    if [ -f "percona80-ubuntu.zip" ]; then
        log_info "解压Percona Server 8.0 (Ubuntu)..."
        unzip -q percona80-ubuntu.zip -d percona80-ubuntu/
    elif [ -f "percona80-ubuntu.xz" ]; then
        log_info "解压Percona Server 8.0 (Ubuntu) (XZ格式)..."
        mkdir -p percona80-ubuntu
        xz -d percona80-ubuntu.xz
        tar -xf percona80-ubuntu -C percona80-ubuntu/
    fi
    
    log_success "所有文件解压完成"
}

# 创建测试数据库和表
setup_test_database() {
    local mysql_host=$1
    local mysql_port=$2
    local mysql_user=$3
    local mysql_password=$4
    
    log_info "设置测试数据库 ($mysql_host:$mysql_port)..."
    
    # 创建测试数据库
    mysql -h"$mysql_host" -P"$mysql_port" -u"$mysql_user" -p"$mysql_password" -e "
        DROP DATABASE IF EXISTS performance_test;
        CREATE DATABASE performance_test;
        USE performance_test;
        
        CREATE TABLE test_table_innodb (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100),
            email VARCHAR(100),
            data TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_name (name),
            INDEX idx_email (email)
        ) ENGINE=InnoDB;
        
        CREATE TABLE test_table_myisam (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100),
            email VARCHAR(100),
            data TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_name (name),
            INDEX idx_email (email)
        ) ENGINE=MyISAM;
        
        CREATE TABLE test_table_memory (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100),
            email VARCHAR(100),
            data VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_name (name),
            INDEX idx_email (email)
        ) ENGINE=Memory;
    "
    
    log_success "测试数据库设置完成"
}

# 运行sysbench测试
run_sysbench_test() {
    local mysql_host=$1
    local mysql_port=$2
    local mysql_user=$3
    local mysql_password=$4
    local table_name=$5
    local engine_name=$6
    
    log_info "运行sysbench测试 - $engine_name 存储引擎..."
    
    local test_name="sysbench_${engine_name}_$(date +%Y%m%d_%H%M%S)"
    local result_file="/tmp/mysql_test_results/${test_name}.log"
    
    mkdir -p /tmp/mysql_test_results
    
    # 准备测试数据
    sysbench oltp_read_write \
        --mysql-host="$mysql_host" \
        --mysql-port="$mysql_port" \
        --mysql-user="$mysql_user" \
        --mysql-password="$mysql_password" \
        --mysql-db=performance_test \
        --tables=1 \
        --table-size=100000 \
        --threads=16 \
        prepare > "$result_file" 2>&1
    
    # 运行测试
    sysbench oltp_read_write \
        --mysql-host="$mysql_host" \
        --mysql-port="$mysql_port" \
        --mysql-user="$mysql_user" \
        --mysql-password="$mysql_password" \
        --mysql-db=performance_test \
        --tables=1 \
        --table-size=100000 \
        --threads=16 \
        --time=300 \
        --report-interval=10 \
        run >> "$result_file" 2>&1
    
    # 清理测试数据
    sysbench oltp_read_write \
        --mysql-host="$mysql_host" \
        --mysql-port="$mysql_port" \
        --mysql-user="$mysql_user" \
        --mysql-password="$mysql_password" \
        --mysql-db=performance_test \
        cleanup >> "$result_file" 2>&1
    
    log_success "sysbench测试完成，结果保存到: $result_file"
}

# 生成性能报告
generate_performance_report() {
    log_info "生成性能测试报告..."
    
    local report_file="/tmp/mysql_test_results/performance_report_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << 'EOF'
# MySQL性能测试报告

## 测试环境

- 测试时间: $(date)
- 操作系统: $(uname -a)
- CPU信息: $(lscpu | grep "Model name" | cut -d: -f2 | xargs)
- 内存信息: $(free -h | grep "Mem:" | awk '{print $2}')

## 测试结果

### 系统资源使用情况

EOF

    # 添加系统信息
    echo "- CPU: $(nproc) 核心" >> "$report_file"
    echo "- 内存: $(free -h | grep "Mem:" | awk '{print $2}')" >> "$report_file"
    echo "- 磁盘: $(df -h / | tail -1 | awk '{print $2}')" >> "$report_file"
    echo "" >> "$report_file"
    
    # 添加测试结果文件列表
    echo "### 测试结果文件" >> "$report_file"
    echo "" >> "$report_file"
    
    for result_file in /tmp/mysql_test_results/*.log; do
        if [ -f "$result_file" ]; then
            echo "- $(basename "$result_file")" >> "$result_file"
        fi
    done
    
    log_success "性能测试报告生成完成: $report_file"
}

# 主函数
main() {
    log_info "开始MySQL性能测试..."
    log_info "测试基于GitHub Release: 20250823_2217_mysql"
    
    # 检查依赖
    check_dependencies
    
    # 下载MySQL版本
    download_mysql_versions
    
    # 验证文件格式
    verify_file_format
    
    # 解压文件
    extract_files
    
    log_info "文件下载和解压完成。"
    log_info "请手动启动各个MySQL实例，然后运行以下命令进行性能测试："
    log_info ""
    log_info "1. 设置测试数据库:"
    log_info "   setup_test_database <host> <port> <user> <password>"
    log_info ""
    log_info "2. 运行性能测试:"
    log_info "   run_sysbench_test <host> <port> <user> <password> <table_name> <engine_name>"
    log_info ""
    log_info "3. 生成报告:"
    log_info "   generate_performance_report"
    
    log_success "MySQL性能测试准备工作完成！"
}

# 如果直接运行脚本，执行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi