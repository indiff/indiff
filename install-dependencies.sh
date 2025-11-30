#!/bin/bash
# MySQL性能测试框架依赖安装脚本
# 自动检测系统类型并安装必要的依赖包

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    exit 1
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/redhat-release ]]; then
        echo "centos"
    elif [[ -f /etc/debian_version ]]; then
        echo "ubuntu"
    elif [[ -f /etc/os-release ]]; then
        local id=$(grep ^ID= /etc/os-release | cut -d'=' -f2 | tr -d '"')
        case "$id" in
            centos|rhel|fedora)
                echo "centos"
                ;;
            ubuntu|debian)
                echo "ubuntu"
                ;;
            *)
                echo "unknown"
                ;;
        esac
    else
        echo "unknown"
    fi
}

# 检查是否有root权限
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此脚本需要root权限运行，请使用 sudo $0"
    fi
}

# 安装CentOS/RHEL依赖
install_centos_deps() {
    log "检测到CentOS/RHEL系统，开始安装依赖..."
    
    # 更新yum源
    yum update -y
    
    # 安装EPEL源
    yum install -y epel-release || {
        warn "EPEL源安装失败，尝试手动安装..."
        yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm
    }
    
    # 基础工具
    log "安装基础工具..."
    yum install -y \
        curl \
        wget \
        unzip \
        bc \
        jq \
        net-tools \
        lsof \
        vim \
        tree \
        htop
    
    # MySQL客户端
    log "安装MySQL客户端..."
    yum install -y mysql || {
        warn "标准MySQL客户端安装失败，尝试MariaDB客户端..."
        yum install -y mariadb
    }
    
    # Sysbench (性能测试工具)
    log "安装Sysbench..."
    if ! yum install -y sysbench; then
        warn "从标准源安装sysbench失败，尝试编译安装..."
        install_sysbench_from_source
    fi
    
    # 开发工具（如果需要编译）
    log "安装开发工具..."
    yum groupinstall -y "Development Tools" || yum install -y gcc gcc-c++ make
    yum install -y \
        mysql-devel \
        openssl-devel \
        zlib-devel \
        libaio-devel
    
    # 其他有用工具
    log "安装其他工具..."
    yum install -y \
        iotop \
        iostat \
        nmon \
        dstat || warn "部分监控工具安装失败，不影响主要功能"
}

# 安装Ubuntu/Debian依赖
install_ubuntu_deps() {
    log "检测到Ubuntu/Debian系统，开始安装依赖..."
    
    # 更新包列表
    apt-get update
    
    # 基础工具
    log "安装基础工具..."
    apt-get install -y \
        curl \
        wget \
        unzip \
        bc \
        jq \
        net-tools \
        lsof \
        vim \
        tree \
        htop
    
    # MySQL客户端
    log "安装MySQL客户端..."
    apt-get install -y mysql-client || {
        warn "MySQL客户端安装失败，尝试MariaDB客户端..."
        apt-get install -y mariadb-client
    }
    
    # Sysbench (性能测试工具)
    log "安装Sysbench..."
    if ! apt-get install -y sysbench; then
        warn "从标准源安装sysbench失败，尝试编译安装..."
        install_sysbench_from_source
    fi
    
    # 开发工具（如果需要编译）
    log "安装开发工具..."
    apt-get install -y \
        build-essential \
        libmysqlclient-dev \
        libssl-dev \
        zlib1g-dev \
        libaio-dev \
        pkg-config
    
    # 其他有用工具
    log "安装其他工具..."
    apt-get install -y \
        iotop \
        sysstat \
        nmon \
        dstat || warn "部分监控工具安装失败，不影响主要功能"
}

# 从源码编译安装sysbench
install_sysbench_from_source() {
    log "从源码编译安装sysbench..."
    
    local build_dir="/tmp/sysbench-build"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # 下载sysbench源码
    if [[ ! -f "sysbench-1.0.20.tar.gz" ]]; then
        wget https://github.com/akopytov/sysbench/archive/1.0.20.tar.gz -O sysbench-1.0.20.tar.gz
    fi
    
    tar -xzf sysbench-1.0.20.tar.gz
    cd sysbench-1.0.20
    
    # 编译安装
    ./autogen.sh
    ./configure --with-mysql
    make -j$(nproc)
    make install
    
    # 创建软链接
    ln -sf /usr/local/bin/sysbench /usr/bin/sysbench
    
    # 更新库路径
    echo "/usr/local/lib" > /etc/ld.so.conf.d/sysbench.conf
    ldconfig
    
    cd /
    rm -rf "$build_dir"
    
    log "Sysbench编译安装完成"
}

# 安装pandoc (用于报告格式转换)
install_pandoc() {
    log "安装Pandoc (用于HTML报告生成)..."
    
    local os_type=$(detect_os)
    case "$os_type" in
        "centos")
            # 下载并安装pandoc rpm包
            local pandoc_url="https://github.com/jgm/pandoc/releases/download/2.19.2/pandoc-2.19.2-linux-amd64.tar.gz"
            wget "$pandoc_url" -O /tmp/pandoc.tar.gz
            cd /tmp
            tar -xzf pandoc.tar.gz
            cp pandoc-2.19.2/bin/pandoc /usr/local/bin/
            rm -rf pandoc*
            ;;
        "ubuntu")
            apt-get install -y pandoc || {
                warn "Pandoc安装失败，HTML报告功能将不可用"
            }
            ;;
    esac
}

# 配置系统参数
configure_system() {
    log "配置系统参数..."
    
    # 调整系统限制
    cat >> /etc/security/limits.conf << EOF
# MySQL性能测试相关配置
mysql soft nofile 65535
mysql hard nofile 65535
mysql soft nproc 32768
mysql hard nproc 32768
EOF
    
    # 调整内核参数
    cat >> /etc/sysctl.conf << EOF

# MySQL性能测试优化参数
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 5000
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
EOF
    
    # 应用sysctl配置
    sysctl -p &>/dev/null || warn "部分内核参数设置失败"
    
    log "系统参数配置完成"
}

# 验证安装
verify_installation() {
    log "验证安装结果..."
    
    local missing_tools=()
    local required_tools=("curl" "unzip" "bc" "jq" "mysql" "sysbench")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        log "所有必需工具安装成功 ✓"
        
        # 显示版本信息
        echo ""
        echo -e "${BLUE}=== 工具版本信息 ===${NC}"
        mysql --version 2>/dev/null || echo "MySQL: 未安装"
        sysbench --version 2>/dev/null || echo "Sysbench: 未安装"
        jq --version 2>/dev/null || echo "JQ: 未安装"
        
        echo ""
        log "依赖安装完成！现在可以运行性能测试："
        echo "  ./mysql-performance-test.sh init"
        echo "  ./mysql-performance-test.sh install"
        echo "  ./mysql-performance-test.sh test"
        
    else
        error "以下工具安装失败: ${missing_tools[*]}"
    fi
}

# 主函数
main() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "MySQL性能测试框架 - 依赖安装脚本"
    echo "=================================================="
    echo -e "${NC}"
    
    # 检查root权限
    check_root
    
    # 检测操作系统
    local os_type=$(detect_os)
    log "检测到操作系统类型: $os_type"
    
    case "$os_type" in
        "centos")
            install_centos_deps
            ;;
        "ubuntu")
            install_ubuntu_deps
            ;;
        *)
            error "不支持的操作系统类型: $os_type"
            ;;
    esac
    
    # 安装pandoc
    install_pandoc
    
    # 配置系统参数
    configure_system
    
    # 验证安装
    verify_installation
    
    echo ""
    log "安装脚本执行完成！"
}

# 如果直接运行脚本
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi