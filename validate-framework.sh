#!/bin/bash

# MySQL vs Percona Performance Testing Framework Validation
# 验证性能测试框架是否正常工作

set -e

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# 验证文件结构
validate_structure() {
    log_info "验证项目文件结构..."
    
    local required_files=(
        "scripts/mysql-performance-test.sh"
        "docker-compose.yml"
        "config/mysql.cnf"
        "config/percona.cnf"
        "config/prometheus.yml"
        "docs/PERFORMANCE_TESTING.md"
        "quick-start.sh"
        ".github/workflows/mysql-percona-performance-test.yml"
    )
    
    local missing_files=()
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -eq 0 ]; then
        log "所有必需文件都存在"
    else
        log_error "缺少以下文件:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        return 1
    fi
}

# 验证脚本权限
validate_permissions() {
    log_info "验证脚本执行权限..."
    
    local scripts=(
        "scripts/mysql-performance-test.sh"
        "quick-start.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -x "$script" ]; then
            log "$script 具有执行权限"
        else
            log_error "$script 缺少执行权限"
            return 1
        fi
    done
}

# 验证 Docker 环境
validate_docker() {
    log_info "验证 Docker 环境..."
    
    if command -v docker &> /dev/null; then
        log "Docker 已安装: $(docker --version)"
    else
        log_error "Docker 未安装"
        return 1
    fi
    
    if docker info &> /dev/null; then
        log "Docker 服务运行正常"
    else
        log_error "Docker 服务未运行"
        return 1
    fi
    
    # 验证 Docker Compose
    if docker compose version &> /dev/null; then
        log "Docker Compose 可用: $(docker compose version)"
    else
        log_error "Docker Compose 不可用"
        return 1
    fi
}

# 验证配置文件语法
validate_configs() {
    log_info "验证配置文件语法..."
    
    # 验证 Docker Compose 配置
    if docker compose config --quiet; then
        log "Docker Compose 配置语法正确"
    else
        log_error "Docker Compose 配置有语法错误"
        return 1
    fi
    
    # 验证 MySQL 配置文件
    if [ -f "config/mysql.cnf" ]; then
        if grep -q "^\[mysqld\]" "config/mysql.cnf"; then
            log "MySQL 配置文件格式正确"
        else
            log_error "MySQL 配置文件格式错误"
            return 1
        fi
    fi
    
    # 验证 Percona 配置文件
    if [ -f "config/percona.cnf" ]; then
        if grep -q "^\[mysqld\]" "config/percona.cnf"; then
            log "Percona 配置文件格式正确"
        else
            log_error "Percona 配置文件格式错误"
            return 1
        fi
    fi
}

# 验证脚本语法
validate_scripts() {
    log_info "验证脚本语法..."
    
    # 验证主测试脚本
    if bash -n "scripts/mysql-performance-test.sh"; then
        log "主测试脚本语法正确"
    else
        log_error "主测试脚本有语法错误"
        return 1
    fi
    
    # 验证快速启动脚本
    if bash -n "quick-start.sh"; then
        log "快速启动脚本语法正确"
    else
        log_error "快速启动脚本有语法错误"
        return 1
    fi
}

# 验证脚本功能
validate_functionality() {
    log_info "验证脚本基本功能..."
    
    # 测试帮助功能
    if ./scripts/mysql-performance-test.sh --help &> /dev/null; then
        log "性能测试脚本帮助功能正常"
    else
        log_error "性能测试脚本帮助功能异常"
        return 1
    fi
    
    if ./quick-start.sh --help &> /dev/null; then
        log "快速启动脚本帮助功能正常"
    else
        log_error "快速启动脚本帮助功能异常"
        return 1
    fi
}

# 验证文档完整性
validate_documentation() {
    log_info "验证文档完整性..."
    
    if [ -f "docs/PERFORMANCE_TESTING.md" ]; then
        if grep -q "MySQL vs Percona" "docs/PERFORMANCE_TESTING.md"; then
            log "性能测试文档存在且内容完整"
        else
            log_error "性能测试文档内容不完整"
            return 1
        fi
    else
        log_error "缺少性能测试文档"
        return 1
    fi
    
    if [ -f "README.md" ]; then
        if grep -q "性能测试框架" "README.md"; then
            log "README 包含性能测试框架说明"
        else
            log_warn "README 中可能缺少性能测试框架说明"
        fi
    fi
}

# 运行验证测试
run_validation_test() {
    log_info "运行框架验证测试..."
    
    # 创建临时测试报告目录
    mkdir -p /tmp/validation_test_reports
    
    # 检查是否可以创建报告目录
    if [ -d "/tmp/validation_test_reports" ]; then
        log "测试报告目录创建成功"
        rm -rf /tmp/validation_test_reports
    else
        log_error "无法创建测试报告目录"
        return 1
    fi
    
    log "框架基础功能验证通过"
}

# 显示验证报告
show_validation_report() {
    echo ""
    echo "=================================================="
    echo "          MySQL vs Percona 测试框架验证报告"
    echo "=================================================="
    echo ""
    echo "验证时间: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "✅ 验证项目:"
    echo "   - 文件结构完整性"
    echo "   - 脚本执行权限"
    echo "   - Docker 环境"
    echo "   - 配置文件语法"
    echo "   - 脚本语法正确性"
    echo "   - 基本功能测试"
    echo "   - 文档完整性"
    echo ""
    echo "🚀 框架已准备就绪，可以开始性能测试!"
    echo ""
    echo "快速开始:"
    echo "  ./quick-start.sh --quick    # 快速测试"
    echo "  ./quick-start.sh           # 标准测试"
    echo "  ./quick-start.sh --monitor # 启动监控"
    echo ""
}

# 主函数
main() {
    echo "MySQL vs Percona 性能测试框架验证"
    echo "======================================"
    echo ""
    
    # 检查是否在正确的目录
    if [ ! -f "scripts/mysql-performance-test.sh" ]; then
        log_error "请在项目根目录下运行此脚本"
        exit 1
    fi
    
    # 运行所有验证
    local validation_steps=(
        "validate_structure"
        "validate_permissions"
        "validate_docker"
        "validate_configs"
        "validate_scripts"
        "validate_functionality"
        "validate_documentation"
        "run_validation_test"
    )
    
    local failed_steps=()
    
    for step in "${validation_steps[@]}"; do
        if ! $step; then
            failed_steps+=("$step")
        fi
    done
    
    echo ""
    
    if [ ${#failed_steps[@]} -eq 0 ]; then
        log "所有验证步骤通过！"
        show_validation_report
        exit 0
    else
        log_error "以下验证步骤失败:"
        for step in "${failed_steps[@]}"; do
            echo "  - $step"
        done
        echo ""
        log_error "请修复上述问题后重新运行验证"
        exit 1
    fi
}

# 运行主函数
main "$@"