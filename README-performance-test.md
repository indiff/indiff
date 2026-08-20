# MySQL数据库性能测试框架

这是一个全面的MySQL数据库性能测试框架，专门用于测试和对比不同MySQL版本和存储引擎的性能表现。

## 支持的数据库版本

### CentOS 7 版本
- **Facebook MySQL 5.6** - Facebook定制版本，集成RocksDB存储引擎
- **MariaDB 10.x** - MySQL的开源分支，功能丰富
- **Oracle MySQL 8.0** - Oracle官方最新版本
- **Percona Server 8.0** - MySQL增强版本，性能监控工具完善

### Ubuntu 版本  
- **Percona Server 8.0** - Ubuntu环境下的Percona版本

## 支持的存储引擎

- **InnoDB** - 支持事务的默认存储引擎
- **MyISAM** - 高性能的读取优化引擎
- **RocksDB** - 基于LSM树的写入优化引擎

## 测试特性

### 性能基准测试
- 使用sysbench进行标准化测试
- 支持多种工作负载类型：
  - `oltp_read_only` - 只读测试
  - `oltp_write_only` - 只写测试
  - `oltp_read_write` - 混合读写测试
  - `oltp_point_select` - 点查询测试
  - `oltp_insert` - 插入测试

### 并发扩展性测试
- 支持1-32线程的并发测试
- 评估多线程环境下的性能扩展能力

### 稳定性测试
- 长时间运行测试（1小时）
- 监控数据库在持续负载下的稳定性

### 自定义SQL测试
- INSERT/SELECT/UPDATE操作性能测试
- 真实业务场景模拟

## 系统要求

### 硬件要求
- **CPU**: 4核以上，推荐8核+
- **内存**: 8GB以上，推荐16GB+
- **存储**: SSD存储，至少50GB可用空间
- **网络**: 稳定的互联网连接（用于下载数据库文件）

### 软件要求
```bash
# CentOS/RHEL
sudo yum install -y curl unzip bc jq mysql sysbench netstat-nat

# Ubuntu/Debian  
sudo apt-get install -y curl unzip bc jq mysql-client sysbench net-tools
```

## 快速开始

### 1. 克隆项目
```bash
git clone https://github.com/indiff/indiff.git
cd indiff
```

### 2. 安装依赖
```bash
# 自动安装依赖（推荐）
sudo ./install-dependencies.sh

# 或手动安装
sudo yum install -y curl unzip bc jq mysql sysbench  # CentOS
sudo apt-get install -y curl unzip bc jq mysql-client sysbench  # Ubuntu
```

### 3. 初始化测试环境
```bash
./mysql-performance-test.sh init
```

### 4. 下载并安装数据库
```bash
# 下载所有数据库版本（需要网络连接）
./mysql-performance-test.sh download

# 安装数据库
./mysql-performance-test.sh install
```

### 5. 运行性能测试
```bash
# 运行完整的性能测试套件（需要较长时间）
./mysql-performance-test.sh test
```

### 6. 生成测试报告
```bash
# 生成中文性能测试报告
./mysql-performance-test.sh report
```

## 详细使用说明

### 主脚本命令

```bash
./mysql-performance-test.sh <命令>
```

**可用命令:**
- `init` - 初始化测试环境
- `download` - 下载所有数据库版本
- `install` - 下载并安装所有数据库
- `test` - 运行完整性能测试
- `report` - 生成测试报告  
- `clean` - 清理测试环境

### 数据库管理

```bash
# 查看数据库状态
./performance-tests/database-manager.sh status

# 启动所有数据库
./performance-tests/database-manager.sh start

# 启动特定数据库
./performance-tests/database-manager.sh start percona80-centos7

# 停止所有数据库
./performance-tests/database-manager.sh stop

# 监控数据库性能
./performance-tests/database-manager.sh monitor percona80-centos7 300
```

### 单独运行测试

```bash
# 只运行基准测试
./performance-tests/run-benchmark.sh

# 只生成报告
./performance-tests/generate-report.sh
```

## 测试结果

测试完成后，所有结果将保存在 `performance-results/` 目录中：

```
performance-results/
├── mysql-performance-report.md     # 中文性能测试报告
├── mysql-performance-report.html   # HTML格式报告（如果安装了pandoc）
├── logs/                          # 测试日志
│   ├── main.log                   # 主日志文件
│   ├── benchmark.log              # 基准测试日志
│   └── *_mysql.log               # 各数据库的MySQL日志
└── *.json                        # 原始测试数据文件
```

### 报告内容

生成的性能测试报告包含以下内容：

1. **执行摘要** - 测试概览和关键发现
2. **测试环境** - 硬件和软件环境信息
3. **性能对比表** - 不同测试场景的详细数据
4. **线程扩展性分析** - 多线程性能扩展能力
5. **稳定性测试分析** - 长时间运行稳定性评估
6. **存储引擎对比分析** - InnoDB vs MyISAM vs RocksDB
7. **数据库版本对比分析** - 各数据库版本优缺点
8. **配置推荐** - 不同场景的最佳实践建议

## 性能调优建议

### 硬件优化
- 使用SSD存储提升I/O性能
- 增加内存容量，推荐数据集大小的2-3倍
- 使用多核CPU提升并发处理能力

### 系统配置
```bash
# 调整系统限制
echo 'mysql soft nofile 65535' >> /etc/security/limits.conf
echo 'mysql hard nofile 65535' >> /etc/security/limits.conf

# 调整内核参数
echo 'net.core.somaxconn = 65535' >> /etc/sysctl.conf
echo 'vm.swappiness = 1' >> /etc/sysctl.conf
sysctl -p
```

### MySQL配置优化
```ini
# InnoDB优化
innodb_buffer_pool_size = 70%内存大小
innodb_log_file_size = 256M
innodb_flush_log_at_trx_commit = 2
innodb_io_capacity = 2000

# 查询缓存（MySQL 5.7及以下）
query_cache_size = 128M
query_cache_type = 1

# 连接配置
max_connections = 1000
thread_cache_size = 128
```

## 故障排除

### 常见问题

**1. 数据库启动失败**
```bash
# 检查错误日志
tail -f /tmp/mysql-performance-test/*/data/error.log

# 清理数据目录重新初始化
rm -rf /tmp/mysql-performance-test/*/data
./mysql-performance-test.sh install
```

**2. 无法连接数据库**
```bash
# 检查进程状态
./performance-tests/database-manager.sh status

# 检查端口占用
netstat -tlnp | grep -E '3306|3307|3308|3309|3310'

# 重启数据库
./performance-tests/database-manager.sh restart
```

**3. 测试运行缓慢**
```bash
# 调整测试参数（编辑脚本）
TEST_DURATION=60     # 减少测试时间
TABLE_SIZE=100000    # 减少测试数据量
```

**4. 内存不足**
```bash
# 监控内存使用
free -h
top -p $(pgrep mysqld)

# 调整缓冲池大小
# 编辑各数据库的my.cnf文件
innodb_buffer_pool_size = 256M  # 减少内存使用
```

### 获取帮助

如果遇到问题，可以：

1. 检查日志文件: `performance-results/logs/`
2. 查看GitHub Issues: https://github.com/indiff/indiff/issues
3. 联系维护者:
   - 邮箱: indiff@126.com
   - QQ: 531299332
   - 微信: adgmtt

## 贡献指南

欢迎提交Issue和Pull Request来改进这个项目：

1. Fork项目
2. 创建特性分支: `git checkout -b feature/amazing-feature`
3. 提交更改: `git commit -m 'Add amazing feature'`
4. 推送分支: `git push origin feature/amazing-feature`
5. 创建Pull Request

## 许可证

本项目采用MIT许可证，详见 [LICENSE](LICENSE) 文件。

## 更新日志

### v1.0.0 (2025-09-25)
- 初始版本发布
- 支持5种MySQL数据库版本测试
- 支持3种存储引擎对比
- 完整的性能基准测试套件
- 中文测试报告生成
- 数据库管理工具

---

**免责声明**: 本测试框架仅用于性能评估和学习目的。在生产环境中使用前，请充分测试并根据实际需求调整配置。