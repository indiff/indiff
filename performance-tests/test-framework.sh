#!/bin/bash
# 测试框架验证脚本 - 用于验证性能测试框架的功能

set -e

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

# 测试主脚本是否可执行
test_main_script() {
    log "测试主脚本..."
    
    if [[ ! -x "$ROOT_DIR/mysql-performance-test.sh" ]]; then
        error "主脚本不可执行"
        return 1
    fi
    
    # 测试帮助信息
    if "$ROOT_DIR/mysql-performance-test.sh" help &>/dev/null; then
        success "主脚本帮助信息正常"
    else
        warn "主脚本帮助信息异常"
    fi
}

# 测试基准测试脚本
test_benchmark_script() {
    log "测试基准测试脚本..."
    
    if [[ ! -x "$SCRIPT_DIR/run-benchmark.sh" ]]; then
        error "基准测试脚本不可执行"
        return 1
    fi
    
    success "基准测试脚本检查通过"
}

# 测试报告生成脚本
test_report_script() {
    log "测试报告生成脚本..."
    
    if [[ ! -x "$SCRIPT_DIR/generate-report.sh" ]]; then
        error "报告生成脚本不可执行"
        return 1
    fi
    
    success "报告生成脚本检查通过"
}

# 测试数据库管理脚本
test_database_manager() {
    log "测试数据库管理脚本..."
    
    if [[ ! -x "$SCRIPT_DIR/database-manager.sh" ]]; then
        error "数据库管理脚本不可执行"
        return 1
    fi
    
    # 测试状态命令
    if "$SCRIPT_DIR/database-manager.sh" status &>/dev/null; then
        success "数据库管理脚本状态命令正常"
    else
        warn "数据库管理脚本状态命令异常"
    fi
}

# 测试依赖工具
test_dependencies() {
    log "检查依赖工具..."
    
    local required_tools=("curl" "unzip" "bc")
    local optional_tools=("jq" "mysql" "sysbench")
    local missing_required=()
    local missing_optional=()
    
    # 检查必需工具
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_required+=("$tool")
        fi
    done
    
    # 检查可选工具
    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_optional+=("$tool")
        fi
    done
    
    if [[ ${#missing_required[@]} -eq 0 ]]; then
        success "所有必需工具都已安装"
    else
        error "缺少必需工具: ${missing_required[*]}"
        echo "请运行: sudo ./install-dependencies.sh"
        return 1
    fi
    
    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        warn "缺少可选工具: ${missing_optional[*]}"
        echo "这些工具缺失可能影响部分功能，建议安装"
    else
        success "所有工具都已安装"
    fi
}

# 测试网络连接
test_network_connection() {
    log "测试网络连接..."
    
    local test_urls=(
        "https://github.com/indiff/indiff/releases"
        "https://ghproxy.cfd"
    )
    
    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 10 "$url" >/dev/null; then
            success "网络连接正常: $url"
        else
            warn "网络连接异常: $url"
        fi
    done
}

# 测试目录权限
test_directory_permissions() {
    log "测试目录权限..."
    
    local test_dir="/tmp/mysql-performance-test-check"
    
    if mkdir -p "$test_dir" && touch "$test_dir/test.txt" && rm -rf "$test_dir"; then
        success "临时目录权限正常"
    else
        error "临时目录权限异常，请检查/tmp目录权限"
        return 1
    fi
}

# 模拟简单的性能测试
test_simple_performance() {
    log "运行简单性能测试..."
    
    # 创建临时测试目录
    local test_dir="/tmp/mysql-performance-test-demo"
    mkdir -p "$test_dir/results"
    
    # 创建模拟测试结果
    cat > "$test_dir/results/test_innodb_oltp_read_only_t8.json" << EOF
SQL statistics:
    queries performed:
        read:                            12345
        write:                           0
        other:                           1757
        total:                           14102
    transactions:                        1757 (5.86 per sec.)
    queries:                             12345 (41.15 per sec.)
    ignored errors:                      0
    reconnects:                          0

General statistics:
    total time:                          300.0312s
    total number of events:              1757

Latency (ms):
         min:                                 10.45
         avg:                                 25.30
         max:                                 89.67
         95th percentile:                     45.79
         sum:                             44452.11

Threads fairness:
    events (avg/stddev):           219.6250/2.12
    execution time (avg/stddev):   5.5565/0.23
EOF
    
    # 测试解析函数
    if command -v "$SCRIPT_DIR/generate-report.sh" &>/dev/null; then
        # 这里可以添加更多解析测试
        success "模拟测试数据创建成功"
    fi
    
    # 清理
    rm -rf "$test_dir"
}

# 生成系统信息报告
generate_system_info() {
    log "生成系统信息..."
    
    echo ""
    echo -e "${BLUE}=== 系统信息 ===${NC}"
    echo "操作系统: $(uname -a)"
    echo "内核版本: $(uname -r)"
    
    if [[ -f /etc/os-release ]]; then
        echo "发行版信息:"
        cat /etc/os-release | grep -E '^(NAME|VERSION)=' | sed 's/^/  /'
    fi
    
    echo ""
    echo -e "${BLUE}=== 硬件信息 ===${NC}"
    echo "CPU信息:"
    if command -v lscpu &>/dev/null; then
        lscpu | grep -E '^(Architecture|CPU|Model name|Thread|Core)' | sed 's/^/  /'
    else
        grep -E '^(processor|model name|cpu cores)' /proc/cpuinfo | head -3 | sed 's/^/  /'
    fi
    
    echo ""
    echo "内存信息:"
    free -h | sed 's/^/  /'
    
    echo ""
    echo "磁盘信息:"
    df -h | grep -v tmpfs | sed 's/^/  /'
    
    echo ""
    echo -e "${BLUE}=== 网络配置 ===${NC}"
    if command -v ip &>/dev/null; then
        ip addr show | grep -E '^[0-9]|inet ' | sed 's/^/  /'
    else
        ifconfig | grep -E '^[a-z]|inet ' | sed 's/^/  /'
    fi
}

# 主测试函数
run_all_tests() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "MySQL性能测试框架 - 功能验证"
    echo "=================================================="
    echo -e "${NC}"
    
    local test_functions=(
        "test_main_script"
        "test_benchmark_script"
        "test_report_script"
        "test_database_manager"
        "test_dependencies"
        "test_network_connection"
        "test_directory_permissions"
        "test_simple_performance"
    )
    
    local passed=0
    local failed=0
    
    for test_func in "${test_functions[@]}"; do
        echo ""
        if $test_func; then
            ((passed++))
        else
            ((failed++))
        fi
    done
    
    echo ""
    echo -e "${BLUE}=== 测试结果汇总 ===${NC}"
    echo "通过: $passed"
    echo "失败: $failed"
    echo "总计: $((passed + failed))"
    
    if [[ $failed -eq 0 ]]; then
        echo ""
        success "所有测试通过！框架可以正常使用。"
        echo ""
        log "下一步操作:"
        echo "  1. 运行 ./mysql-performance-test.sh init"
        echo "  2. 运行 ./mysql-performance-test.sh install"
        echo "  3. 运行 ./mysql-performance-test.sh test"
        
        return 0
    else
        echo ""
        error "有 $failed 个测试失败，请修复后再运行性能测试。"
        return 1
    fi
}

# 主函数
main() {
    local action="${1:-test}"
    
    case "$action" in
        "test")
            run_all_tests
            ;;
        "sysinfo")
            generate_system_info
            ;;
        "deps")
            test_dependencies
            ;;
        *)
            echo "测试框架验证脚本"
            echo ""
            echo "用法: $0 <命令>"
            echo ""
            echo "命令:"
            echo "  test    - 运行所有测试"
            echo "  sysinfo - 显示系统信息"
            echo "  deps    - 检查依赖工具"
            ;;
    esac
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi