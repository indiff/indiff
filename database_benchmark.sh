#!/bin/bash

# =============================================================================
# 数据库性能基准测试脚本
# Database Performance Benchmark Script
# 
# 用途: 对 MySQL, PostgreSQL, Oracle 进行性能基准测试
# Purpose: Performance benchmarking for MySQL, PostgreSQL, Oracle
# 
# 作者: indiff
# 版本: 1.0
# =============================================================================

set -euo pipefail

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/benchmark_logs"
RESULTS_DIR="${SCRIPT_DIR}/benchmark_results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# 创建目录
mkdir -p "${LOG_DIR}" "${RESULTS_DIR}"

# 颜色输出函数
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "${LOG_DIR}/benchmark_${TIMESTAMP}.log"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "${LOG_DIR}/benchmark_${TIMESTAMP}.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "${LOG_DIR}/benchmark_${TIMESTAMP}.log"
}

log_header() {
    echo -e "${BLUE}=== $1 ===${NC}" | tee -a "${LOG_DIR}/benchmark_${TIMESTAMP}.log"
}

# 数据库连接配置
MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-password}"
MYSQL_DATABASE="${MYSQL_DATABASE:-benchmark_test}"

POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-password}"
POSTGRES_DATABASE="${POSTGRES_DATABASE:-benchmark_test}"

ORACLE_HOST="${ORACLE_HOST:-localhost}"
ORACLE_PORT="${ORACLE_PORT:-1521}"
ORACLE_USER="${ORACLE_USER:-system}"
ORACLE_PASSWORD="${ORACLE_PASSWORD:-password}"
ORACLE_SID="${ORACLE_SID:-XE}"

# sysbench 配置
SYSBENCH_TABLES="${SYSBENCH_TABLES:-10}"
SYSBENCH_TABLE_SIZE="${SYSBENCH_TABLE_SIZE:-1000000}"
SYSBENCH_THREADS="${SYSBENCH_THREADS:-1,8,16,32,64,128}"
SYSBENCH_TIME="${SYSBENCH_TIME:-300}"

# 检查依赖工具
check_dependencies() {
    log_header "检查依赖工具"
    
    local missing_tools=()
    
    if ! command -v sysbench &> /dev/null; then
        missing_tools+=("sysbench")
    fi
    
    if ! command -v mysql &> /dev/null; then
        missing_tools+=("mysql-client")
    fi
    
    if ! command -v psql &> /dev/null; then
        missing_tools+=("postgresql-client")
    fi
    
    if ! command -v sqlplus &> /dev/null; then
        log_warn "Oracle sqlplus 未找到，将跳过 Oracle 测试"
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "缺少必要工具: ${missing_tools[*]}"
        log_info "请安装缺少的工具后重新运行"
        exit 1
    fi
    
    log_info "所有依赖工具检查完成"
}

# 测试数据库连接
test_mysql_connection() {
    log_info "测试 MySQL 连接..."
    if mysql -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "SELECT 1;" 2>/dev/null; then
        log_info "MySQL 连接成功"
        return 0
    else
        log_error "MySQL 连接失败"
        return 1
    fi
}

test_postgres_connection() {
    log_info "测试 PostgreSQL 连接..."
    if PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d postgres -c "SELECT 1;" 2>/dev/null; then
        log_info "PostgreSQL 连接成功"
        return 0
    else
        log_error "PostgreSQL 连接失败"
        return 1
    fi
}

test_oracle_connection() {
    log_info "测试 Oracle 连接..."
    if command -v sqlplus &> /dev/null; then
        echo "SELECT 1 FROM DUAL;" | sqlplus -S "${ORACLE_USER}/${ORACLE_PASSWORD}@${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SID}" 2>/dev/null | grep -q "1" && {
            log_info "Oracle 连接成功"
            return 0
        } || {
            log_error "Oracle 连接失败"
            return 1
        }
    else
        log_warn "Oracle sqlplus 不可用，跳过连接测试"
        return 1
    fi
}

# 准备测试数据
prepare_mysql_data() {
    log_info "准备 MySQL 测试数据..."
    
    # 创建数据库
    mysql -h"${MYSQL_HOST}" -P"${MYSQL_PORT}" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -e "DROP DATABASE IF EXISTS ${MYSQL_DATABASE}; CREATE DATABASE ${MYSQL_DATABASE};"
    
    # 使用 sysbench 准备数据
    sysbench oltp_read_write \
        --mysql-host="${MYSQL_HOST}" \
        --mysql-port="${MYSQL_PORT}" \
        --mysql-user="${MYSQL_USER}" \
        --mysql-password="${MYSQL_PASSWORD}" \
        --mysql-db="${MYSQL_DATABASE}" \
        --tables="${SYSBENCH_TABLES}" \
        --table-size="${SYSBENCH_TABLE_SIZE}" \
        prepare
    
    log_info "MySQL 测试数据准备完成"
}

prepare_postgres_data() {
    log_info "准备 PostgreSQL 测试数据..."
    
    # 创建数据库
    PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d postgres -c "DROP DATABASE IF EXISTS ${POSTGRES_DATABASE};"
    PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d postgres -c "CREATE DATABASE ${POSTGRES_DATABASE};"
    
    # 使用 sysbench 准备数据
    sysbench oltp_read_write \
        --pgsql-host="${POSTGRES_HOST}" \
        --pgsql-port="${POSTGRES_PORT}" \
        --pgsql-user="${POSTGRES_USER}" \
        --pgsql-password="${POSTGRES_PASSWORD}" \
        --pgsql-db="${POSTGRES_DATABASE}" \
        --tables="${SYSBENCH_TABLES}" \
        --table-size="${SYSBENCH_TABLE_SIZE}" \
        prepare
    
    log_info "PostgreSQL 测试数据准备完成"
}

# 运行 MySQL 基准测试
run_mysql_benchmark() {
    local test_name="$1"
    local output_file="${RESULTS_DIR}/mysql_${test_name}_${TIMESTAMP}.txt"
    
    log_header "运行 MySQL ${test_name} 测试"
    
    echo "MySQL ${test_name} 测试结果 - $(date)" > "${output_file}"
    echo "========================================" >> "${output_file}"
    
    IFS=',' read -ra THREAD_ARRAY <<< "${SYSBENCH_THREADS}"
    for threads in "${THREAD_ARRAY[@]}"; do
        log_info "MySQL ${test_name} - 线程数: ${threads}"
        
        echo "线程数: ${threads}" >> "${output_file}"
        echo "--------------------" >> "${output_file}"
        
        sysbench "${test_name}" \
            --mysql-host="${MYSQL_HOST}" \
            --mysql-port="${MYSQL_PORT}" \
            --mysql-user="${MYSQL_USER}" \
            --mysql-password="${MYSQL_PASSWORD}" \
            --mysql-db="${MYSQL_DATABASE}" \
            --tables="${SYSBENCH_TABLES}" \
            --table-size="${SYSBENCH_TABLE_SIZE}" \
            --threads="${threads}" \
            --time="${SYSBENCH_TIME}" \
            --report-interval=10 \
            run >> "${output_file}" 2>&1
        
        echo "" >> "${output_file}"
    done
    
    log_info "MySQL ${test_name} 测试完成，结果保存到: ${output_file}"
}

# 运行 PostgreSQL 基准测试
run_postgres_benchmark() {
    local test_name="$1"
    local output_file="${RESULTS_DIR}/postgresql_${test_name}_${TIMESTAMP}.txt"
    
    log_header "运行 PostgreSQL ${test_name} 测试"
    
    echo "PostgreSQL ${test_name} 测试结果 - $(date)" > "${output_file}"
    echo "===========================================" >> "${output_file}"
    
    IFS=',' read -ra THREAD_ARRAY <<< "${SYSBENCH_THREADS}"
    for threads in "${THREAD_ARRAY[@]}"; do
        log_info "PostgreSQL ${test_name} - 线程数: ${threads}"
        
        echo "线程数: ${threads}" >> "${output_file}"
        echo "--------------------" >> "${output_file}"
        
        sysbench "${test_name}" \
            --pgsql-host="${POSTGRES_HOST}" \
            --pgsql-port="${POSTGRES_PORT}" \
            --pgsql-user="${POSTGRES_USER}" \
            --pgsql-password="${POSTGRES_PASSWORD}" \
            --pgsql-db="${POSTGRES_DATABASE}" \
            --tables="${SYSBENCH_TABLES}" \
            --table-size="${SYSBENCH_TABLE_SIZE}" \
            --threads="${threads}" \
            --time="${SYSBENCH_TIME}" \
            --report-interval=10 \
            run >> "${output_file}" 2>&1
        
        echo "" >> "${output_file}"
    done
    
    log_info "PostgreSQL ${test_name} 测试完成，结果保存到: ${output_file}"
}

# 生成性能报告
generate_performance_report() {
    local report_file="${RESULTS_DIR}/performance_report_${TIMESTAMP}.md"
    
    log_header "生成性能报告"
    
    cat > "${report_file}" << EOF
# 数据库性能测试报告

## 测试环境信息

- **测试时间**: $(date)
- **sysbench 版本**: $(sysbench --version | head -n1)
- **测试表数量**: ${SYSBENCH_TABLES}
- **每表记录数**: ${SYSBENCH_TABLE_SIZE}
- **测试线程数**: ${SYSBENCH_THREADS}
- **测试持续时间**: ${SYSBENCH_TIME} 秒

## 数据库配置

### MySQL
- 主机: ${MYSQL_HOST}:${MYSQL_PORT}
- 数据库: ${MYSQL_DATABASE}
- 用户: ${MYSQL_USER}

### PostgreSQL
- 主机: ${POSTGRES_HOST}:${POSTGRES_PORT}
- 数据库: ${POSTGRES_DATABASE}
- 用户: ${POSTGRES_USER}

### Oracle
- 主机: ${ORACLE_HOST}:${ORACLE_PORT}
- SID: ${ORACLE_SID}
- 用户: ${ORACLE_USER}

## 测试结果摘要

详细的测试结果请查看以下文件：

EOF

    # 添加结果文件链接
    for result_file in "${RESULTS_DIR}"/*_"${TIMESTAMP}".txt; do
        if [ -f "${result_file}" ]; then
            echo "- [$(basename "${result_file}")]($(basename "${result_file}"))" >> "${report_file}"
        fi
    done
    
    cat >> "${report_file}" << EOF

## 性能对比图表

以下脚本可用于生成性能对比图表：

\`\`\`bash
# 安装 gnuplot (如果未安装)
# Ubuntu/Debian: sudo apt-get install gnuplot
# CentOS/RHEL: sudo yum install gnuplot

# 生成 QPS 对比图
gnuplot -e "
set terminal png size 800,600;
set output 'qps_comparison.png';
set title 'QPS Performance Comparison';
set xlabel 'Threads';
set ylabel 'Queries Per Second';
set grid;
plot 'mysql_qps.dat' with linespoints title 'MySQL', \\
     'postgresql_qps.dat' with linespoints title 'PostgreSQL', \\
     'oracle_qps.dat' with linespoints title 'Oracle'
"
\`\`\`

## 结论和建议

基于测试结果，我们可以得出以下结论：

1. **OLTP 性能**: [根据测试结果填写]
2. **并发处理**: [根据测试结果填写]
3. **响应时间**: [根据测试结果填写]
4. **资源使用**: [根据测试结果填写]

### 优化建议

#### MySQL 优化
- 调整 innodb_buffer_pool_size
- 优化 innodb_log_file_size
- 配置适当的连接池大小

#### PostgreSQL 优化
- 调整 shared_buffers
- 优化 effective_cache_size
- 配置 checkpoint 参数

#### Oracle 优化
- 调整 SGA 大小
- 优化 PGA 配置
- 配置 ASM 磁盘组

---

*此报告由自动化测试脚本生成，详细数据请参考原始测试结果文件。*
EOF

    log_info "性能报告生成完成: ${report_file}"
}

# 主函数
main() {
    log_header "数据库性能基准测试开始"
    log_info "测试时间戳: ${TIMESTAMP}"
    
    # 检查依赖
    check_dependencies
    
    # 测试连接
    mysql_available=false
    postgres_available=false
    oracle_available=false
    
    if test_mysql_connection; then
        mysql_available=true
    fi
    
    if test_postgres_connection; then
        postgres_available=true
    fi
    
    if test_oracle_connection; then
        oracle_available=true
    fi
    
    # 如果没有可用的数据库，退出
    if ! $mysql_available && ! $postgres_available && ! $oracle_available; then
        log_error "没有可用的数据库连接，测试终止"
        exit 1
    fi
    
    # 准备测试数据
    if $mysql_available; then
        prepare_mysql_data
    fi
    
    if $postgres_available; then
        prepare_postgres_data
    fi
    
    # 运行基准测试
    log_header "开始基准测试"
    
    # OLTP 读写混合测试
    if $mysql_available; then
        run_mysql_benchmark "oltp_read_write"
    fi
    
    if $postgres_available; then
        run_postgres_benchmark "oltp_read_write"
    fi
    
    # 只读测试
    if $mysql_available; then
        run_mysql_benchmark "oltp_read_only"
    fi
    
    if $postgres_available; then
        run_postgres_benchmark "oltp_read_only"
    fi
    
    # 只写测试
    if $mysql_available; then
        run_mysql_benchmark "oltp_write_only"
    fi
    
    if $postgres_available; then
        run_postgres_benchmark "oltp_write_only"
    fi
    
    # 生成报告
    generate_performance_report
    
    log_header "数据库性能基准测试完成"
    log_info "测试结果保存在: ${RESULTS_DIR}"
    log_info "测试日志保存在: ${LOG_DIR}/benchmark_${TIMESTAMP}.log"
}

# 命令行参数处理
show_help() {
    cat << EOF
数据库性能基准测试脚本

用法: $0 [选项]

选项:
    -h, --help          显示此帮助信息
    --mysql-host        MySQL 主机地址 (默认: localhost)
    --mysql-port        MySQL 端口 (默认: 3306)
    --mysql-user        MySQL 用户名 (默认: root)
    --mysql-password    MySQL 密码 (默认: password)
    --pg-host           PostgreSQL 主机地址 (默认: localhost)
    --pg-port           PostgreSQL 端口 (默认: 5432)
    --pg-user           PostgreSQL 用户名 (默认: postgres)
    --pg-password       PostgreSQL 密码 (默认: password)
    --tables            测试表数量 (默认: 10)
    --table-size        每表记录数 (默认: 1000000)
    --threads           测试线程数 (默认: 1,8,16,32,64,128)
    --time              测试持续时间/秒 (默认: 300)

环境变量:
    MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD
    POSTGRES_HOST, POSTGRES_PORT, POSTGRES_USER, POSTGRES_PASSWORD
    ORACLE_HOST, ORACLE_PORT, ORACLE_USER, ORACLE_PASSWORD, ORACLE_SID

示例:
    $0
    $0 --mysql-host 192.168.1.100 --tables 5 --time 180
    $0 --pg-host db.example.com --threads 1,4,8,16

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        --mysql-host)
            MYSQL_HOST="$2"
            shift 2
            ;;
        --mysql-port)
            MYSQL_PORT="$2"
            shift 2
            ;;
        --mysql-user)
            MYSQL_USER="$2"
            shift 2
            ;;
        --mysql-password)
            MYSQL_PASSWORD="$2"
            shift 2
            ;;
        --pg-host)
            POSTGRES_HOST="$2"
            shift 2
            ;;
        --pg-port)
            POSTGRES_PORT="$2"
            shift 2
            ;;
        --pg-user)
            POSTGRES_USER="$2"
            shift 2
            ;;
        --pg-password)
            POSTGRES_PASSWORD="$2"
            shift 2
            ;;
        --tables)
            SYSBENCH_TABLES="$2"
            shift 2
            ;;
        --table-size)
            SYSBENCH_TABLE_SIZE="$2"
            shift 2
            ;;
        --threads)
            SYSBENCH_THREADS="$2"
            shift 2
            ;;
        --time)
            SYSBENCH_TIME="$2"
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
main "$@"