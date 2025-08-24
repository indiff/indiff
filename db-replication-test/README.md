# 数据库主从同步测试

本测试框架用于测试 Percona Server 与 MariaDB 之间的主从同步功能。

## 测试场景

### 场景1：Percona 主库 → MariaDB 从库
- **主库**: Percona Server 8.0 (InnoDB 存储引擎)
- **从库**: MariaDB (ColumnStore 默认存储引擎)

### 场景2：MariaDB 主库 → Percona 从库  
- **主库**: MariaDB (InnoDB 存储引擎)
- **从库**: Percona Server 8.0 (RocksDB 存储引擎)

## 使用方法

### 快速测试 (推荐)

使用 Docker 环境进行快速测试：

```bash
# 快速测试模式
./test-docker.sh --quick-test

# 清理环境
./test-docker.sh --cleanup
```

### 完整测试

使用本地编译的 Percona Server：

```bash
# 运行完整测试
./test-replication.sh

# 只测试场景1
./test-replication.sh --scenario=1

# 只测试场景2  
./test-replication.sh --scenario=2

# 生成详细报告
./test-replication.sh --detailed-report
```

### 监控和基准测试

```bash
# 监控主从状态
./scripts/monitor-replication.sh

# 性能基准测试
./scripts/benchmark.sh 1
```

## 文件结构

- `test-replication.sh` - 主测试脚本 (本地 Percona Server)
- `test-docker.sh` - Docker 环境测试脚本 (推荐)
- `docker-compose.yml` - Docker Compose 配置
- `configs/` - 数据库配置文件
- `sql/` - 测试用SQL脚本
- `scripts/` - 辅助脚本
  - `monitor-replication.sh` - 主从状态监控
  - `benchmark.sh` - 性能基准测试
- `results/` - 测试结果输出目录

## 测试指标

- 同步延迟
- 数据一致性
- 错误率
- 性能指标
- 稳定性评估