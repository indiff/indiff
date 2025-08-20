# MySQL vs Percona 性能测试框架

这个项目提供了一个完整的框架来对比 MySQL 和 Percona Server 的性能表现，包括并发测试和详细的性能分析报告。

## 📋 功能特性

- 🚀 **自动化性能测试**: 使用 sysbench 进行 OLTP 工作负载测试
- 📊 **多维度对比**: 支持读写混合、只读、只写、插入等多种测试场景
- 🔧 **可配置测试**: 支持自定义测试持续时间、表大小、并发线程数等参数
- 📈 **详细报告**: 生成包含 TPS、延迟、资源使用等指标的详细报告
- 🐳 **容器化测试**: 基于 Docker 确保测试环境的一致性
- ⚡ **CI/CD 集成**: GitHub Actions 自动化测试流程
- 📊 **监控集成**: 集成 Prometheus + Grafana 实时监控

## 🚀 快速开始

### 前置要求

- Docker 和 Docker Compose
- sysbench (用于数据库基准测试)
- bc (用于数学计算)
- jq (用于 JSON 处理)

### 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y docker.io docker-compose sysbench bc jq

# CentOS/RHEL
sudo yum install -y docker docker-compose sysbench bc jq

# 启动 Docker 服务
sudo systemctl start docker
sudo systemctl enable docker
```

### 运行性能测试

#### 方法1: 使用脚本直接测试

```bash
# 克隆仓库
git clone https://github.com/indiff/indiff.git
cd indiff

# 运行默认测试
chmod +x scripts/mysql-performance-test.sh
./scripts/mysql-performance-test.sh

# 运行自定义测试
./scripts/mysql-performance-test.sh \
  --test-duration 600 \
  --table-size 200000 \
  --threads "1 8 16 32 64" \
  --mysql-version 8.0.35 \
  --percona-version 8.0.35
```

#### 方法2: 使用 Docker Compose

```bash
# 启动测试环境
docker-compose up -d

# 在 sysbench 容器中运行测试
docker-compose exec sysbench bash
/scripts/mysql-performance-test.sh

# 停止环境
docker-compose down
```

## 📊 测试场景

测试框架包含以下基准测试场景:

| 测试场景 | 描述 | 适用场景 |
|----------|------|----------|
| `oltp_read_write` | 读写混合工作负载 | 真实业务场景模拟 |
| `oltp_read_only` | 只读工作负载 | 查询密集型应用 |
| `oltp_write_only` | 只写工作负载 | 写密集型应用 |
| `oltp_insert` | 插入测试 | 数据导入场景 |

## 📈 报告说明

每次测试完成后，会在 `performance_reports/test_TIMESTAMP/` 目录下生成以下文件:

```
performance_reports/test_20240120_143022/
├── performance_comparison_report.md    # 主要对比报告
├── mysql_oltp_read_write_threads_1.json       # MySQL 测试原始数据
├── percona_oltp_read_write_threads_1.json     # Percona 测试原始数据
├── mysql_container_stats.txt          # MySQL 容器资源使用情况
├── percona_container_stats.txt        # Percona 容器资源使用情况
├── mysql_innodb_status.txt           # MySQL InnoDB 状态
├── percona_innodb_status.txt         # Percona InnoDB 状态
└── ...
```

### 主要指标说明

- **TPS (Transactions Per Second)**: 每秒事务数，数值越高性能越好
- **延迟 (Latency)**: 平均响应时间，数值越低性能越好
- **CPU 使用率**: 处理器使用百分比
- **内存使用**: 内存占用情况
- **网络 I/O**: 网络传输统计
- **磁盘 I/O**: 磁盘读写统计

## ⚙️ 配置说明

### 数据库配置

测试使用优化的数据库配置:

- **MySQL配置**: `config/mysql.cnf`
- **Percona配置**: `config/percona.cnf`

主要优化项包括:
- InnoDB 缓冲池大小
- 日志文件配置
- 连接数设置
- 线程池配置 (Percona)

### 测试参数

可通过脚本参数自定义测试:

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `--mysql-version` | 8.0 | MySQL 版本 |
| `--percona-version` | 8.0 | Percona 版本 |
| `--test-duration` | 300 | 测试持续时间(秒) |
| `--table-size` | 100000 | 测试表大小 |
| `--threads` | "1 4 8 16 32 64" | 并发线程数 |
| `--report-dir` | ./performance_reports | 报告保存目录 |

## 🔄 CI/CD 集成

项目包含 GitHub Actions 工作流程，支持:

- 🕐 **定时测试**: 每周日凌晨 2 点 (UTC) 自动运行
- 🎯 **手动触发**: 支持手动触发并自定义参数
- 📦 **自动发布**: 测试完成后自动创建 release 并上传报告

### 手动触发测试

1. 访问 GitHub 仓库的 Actions 页面
2. 选择 "MySQL vs Percona Performance Testing" 工作流
3. 点击 "Run workflow" 并设置参数
4. 等待测试完成并查看结果

## 📊 监控和可视化

项目集成了完整的监控解决方案:

### Prometheus + Grafana

```bash
# 启动监控环境
docker-compose up -d prometheus grafana mysql-exporter percona-exporter

# 访问 Grafana
open http://localhost:3000
# 用户名: admin, 密码: admin123

# 访问 Prometheus
open http://localhost:9090
```

### 预配置的监控指标

- 数据库连接数
- 查询执行时间
- InnoDB 缓冲池状态
- 锁等待情况
- 复制延迟
- 系统资源使用

## 🔧 自定义测试

### 添加新的测试场景

1. 修改 `scripts/mysql-performance-test.sh` 中的 `test_types` 数组
2. 添加相应的 sysbench 测试命令
3. 更新报告生成逻辑

### 自定义配置文件

编辑 `config/mysql.cnf` 和 `config/percona.cnf` 来调整数据库配置:

```ini
# 例如: 增加缓冲池大小
innodb_buffer_pool_size = 2G

# 调整并发连接数
max_connections = 1000
```

## 📊 性能优化建议

### MySQL 优化

- 适当增加 `innodb_buffer_pool_size`
- 调整 `innodb_log_file_size` 以减少检查点频率
- 使用 `innodb_flush_log_at_trx_commit = 2` 提高写性能

### Percona 特有优化

- 启用 `thread_handling = pool-of-threads`
- 使用 `innodb_adaptive_hash_index = ON`
- 配置 `userstat = 1` 获取详细统计信息

## 🐛 故障排查

### 常见问题

1. **容器启动失败**
   ```bash
   # 检查端口占用
   sudo netstat -tlnp | grep :3306
   # 清理旧容器
   docker system prune -a
   ```

2. **sysbench 连接失败**
   ```bash
   # 检查数据库是否已启动
   docker logs mysql_perf_test_mysql
   # 测试连接
   docker exec mysql_perf_test_mysql mysqladmin ping -u root -ptest123
   ```

3. **内存不足**
   ```bash
   # 减少测试规模
   ./scripts/mysql-performance-test.sh --table-size 50000 --threads "1 4 8"
   ```

## 📖 参考资料

- [Sysbench Documentation](https://github.com/akopytov/sysbench)
- [MySQL Performance Tuning](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)
- [Percona Server Documentation](https://docs.percona.com/percona-server/8.0/)
- [Docker Compose Reference](https://docs.docker.com/compose/)

## 🤝 贡献

欢迎提交 Issues 和 Pull Requests 来改进这个测试框架!

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。