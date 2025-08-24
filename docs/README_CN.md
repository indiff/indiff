# MySQL vs Percona vs MariaDB 三数据库并发性能测试框架

本框架实现了 MySQL 8.0、Percona Server 8.0 和 MariaDB 最新版的综合性能对比测试，支持多种存储引擎的并发性能测试。

## 🎯 项目特点

### 全面的数据库对比
- **MySQL 8.0**: 业界标准的开源关系型数据库
- **Percona Server 8.0**: 基于 MySQL 的高性能版本，包含 RocksDB 存储引擎
- **MariaDB 最新版**: MySQL 的开源分支，包含 ColumnStore 分析引擎

### 多存储引擎支持
- **InnoDB**: 通用事务型存储引擎，适合 OLTP 工作负载
- **RocksDB**: LSM-tree 基础的存储引擎，写性能优秀
- **ColumnStore**: 列式存储引擎，专门针对分析型查询优化

### 预编译 Percona 集成
- 使用预编译的 CentOS7 版本 Percona Server
- 包含完整的 RocksDB 支持
- 下载地址: `https://github.com/indiff/indiff/releases/download/20250821_0401_percona80/percona80-centos7-x86_64-20250821_0358.xz`

## 🚀 快速开始

### 环境要求
- Docker 和 Docker Compose
- sysbench (性能测试工具)
- 至少 4GB 可用内存
- 至少 10GB 可用磁盘空间

### 安装依赖

#### Ubuntu/Debian:
```bash
sudo apt update
sudo apt install docker.io docker-compose sysbench jq bc
sudo systemctl start docker
sudo usermod -aG docker $USER
```

#### CentOS/RHEL:
```bash
sudo yum install docker docker-compose sysbench jq bc
sudo systemctl start docker
sudo usermod -aG docker $USER
```

### 运行测试

#### 1. 快速测试 (1分钟)
```bash
./quick-start.sh --quick
```

#### 2. 标准测试 (5分钟) 
```bash
./quick-start.sh
```

#### 3. 深度测试 (30分钟)
```bash
./quick-start.sh --long
```

#### 4. 传统双数据库测试
```bash
./quick-start.sh --legacy
```

## 🛠️ 高级用法

### 自定义测试参数
```bash
./scripts/enhanced-mysql-performance-test.sh \
  --test-duration 600 \
  --table-size 200000 \
  --threads "1 8 16 32 64" \
  --mysql-version 8.0.35 \
  --mariadb-version 11.1
```

### 启动监控环境
```bash
./quick-start.sh --monitor
```

访问监控界面:
- Grafana: http://localhost:3000 (admin/admin123)
- Prometheus: http://localhost:9090

### 使用 Docker Compose
```bash
./quick-start.sh --compose
```

### 清理环境
```bash
./quick-start.sh --cleanup
```

## 📊 测试场景

### 1. OLTP 工作负载测试
- **读写混合** (oltp_read_write): 模拟真实应用的混合读写操作
- **只读测试** (oltp_read_only): 测试数据库的查询性能
- **只写测试** (oltp_write_only): 测试数据库的写入性能
- **插入测试** (oltp_insert): 测试批量插入性能

### 2. 存储引擎专项测试
- **InnoDB vs RocksDB**: 对比传统 B-tree 和 LSM-tree 存储结构
- **ColumnStore 分析查询**: 测试列式存储在分析场景下的性能

### 3. 并发性能测试
- 支持 1-128 个并发线程
- 可配置测试持续时间 (60秒-1800秒)
- 可配置测试数据大小 (10K-500K 行)

## 📈 报告生成

### 自动生成报告类型
1. **综合性能对比报告** (`comprehensive_performance_report.md`)
2. **各数据库系统信息** (全局状态、变量、引擎信息)
3. **容器资源使用统计**
4. **存储引擎专项分析**

### 报告内容
- TPS (每秒事务数) 对比
- 平均延迟对比
- 性能提升百分比
- 系统资源消耗分析
- 存储引擎特性对比

## 🔧 配置文件

### 数据库配置
- `config/mysql.cnf`: MySQL 8.0 性能优化配置
- `config/percona.cnf`: Percona Server 配置，包含 RocksDB 设置
- `config/mariadb.cnf`: MariaDB 配置，包含 ColumnStore 设置

### 监控配置
- `config/prometheus.yml`: Prometheus 监控配置
- `config/grafana/`: Grafana 仪表板和数据源配置

## 🐳 Docker 架构

### 数据库容器
- `mysql_performance_test`: MySQL 8.0 (端口 3306)
- `percona_performance_test`: Percona Server 8.0 (端口 3307)
- `mariadb_performance_test`: MariaDB latest (端口 3308)

### 工具容器
- `sysbench_tester`: 性能测试工具容器
- `prometheus_monitor`: 指标收集服务
- `grafana_dashboard`: 可视化仪表板

### 监控容器
- `mysql_exporter`: MySQL 指标导出器 (端口 9104)
- `percona_exporter`: Percona 指标导出器 (端口 9105)
- `mariadb_exporter`: MariaDB 指标导出器 (端口 9106)

## 📝 测试结果示例

### InnoDB 存储引擎对比
| 线程数 | MySQL TPS | Percona TPS | MariaDB TPS | 性能提升 |
|--------|-----------|-------------|-------------|----------|
| 1      | 1,234.56  | 1,345.67    | 1,289.45    | +9.0%    |
| 8      | 8,765.43  | 9,234.21    | 8,901.32    | +5.3%    |
| 32     | 15,432.10 | 16,789.45   | 15,678.92   | +8.8%    |

### RocksDB vs InnoDB (Percona)
| 线程数 | InnoDB TPS | RocksDB TPS | 写入性能提升 |
|--------|------------|-------------|-------------|
| 1      | 1,345.67   | 1,567.89    | +16.5%      |
| 8      | 9,234.21   | 11,456.78   | +24.1%      |
| 32     | 16,789.45  | 21,234.56   | +26.5%      |

## 🚨 注意事项

### 系统要求
- 确保有足够的内存运行三个数据库实例
- 建议在 SSD 硬盘上运行测试
- 关闭系统的 swap 以获得准确的性能数据

### 网络要求
- 确保 Docker 网络正常工作
- 防火墙允许容器间通信
- 监控端口 (3000, 9090, 9104-9106) 可访问

### 测试建议
- 首次运行建议使用快速测试验证环境
- 生产环境测试建议在业务低峰期进行
- 长时间测试需要确保系统稳定性

## 🛡️ 故障排除

### 常见问题

#### 1. 容器启动失败
```bash
# 检查 Docker 状态
sudo systemctl status docker

# 查看容器日志
docker logs mysql_performance_test
docker logs percona_performance_test  
docker logs mariadb_performance_test
```

#### 2. 端口冲突
```bash
# 检查端口占用
netstat -tulpn | grep -E ':(3306|3307|3308|9090|3000)'

# 停止冲突服务
sudo systemctl stop mysql
sudo systemctl stop mariadb
```

#### 3. 内存不足
```bash
# 检查可用内存
free -h

# 调整测试参数
./scripts/enhanced-mysql-performance-test.sh --table-size 50000 --threads "1 4 8"
```

#### 4. 测试数据准备失败
```bash
# 手动清理测试数据
docker exec mysql_performance_test mysql -u root -ptest123 -e "DROP DATABASE IF EXISTS performance_test; CREATE DATABASE performance_test;"
```

## 📚 相关资源

### 文档链接
- [MySQL 8.0 文档](https://dev.mysql.com/doc/refman/8.0/en/)
- [Percona Server 文档](https://docs.percona.com/percona-server/8.0/)
- [MariaDB 文档](https://mariadb.com/kb/en/documentation/)
- [sysbench 文档](https://github.com/akopytov/sysbench)

### 存储引擎资源
- [RocksDB 文档](https://rocksdb.org/)
- [MariaDB ColumnStore 文档](https://mariadb.com/kb/en/columnstore/)
- [InnoDB 存储引擎](https://dev.mysql.com/doc/refman/8.0/en/innodb-storage-engine.html)

### 性能调优指南
- [MySQL 性能调优](https://dev.mysql.com/doc/refman/8.0/en/optimization.html)
- [Percona 最佳实践](https://docs.percona.com/percona-server/8.0/performance-best-practices.html)
- [MariaDB 性能优化](https://mariadb.com/kb/en/optimization-and-tuning/)

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个测试框架。

### 贡献指南
1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 打开 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。