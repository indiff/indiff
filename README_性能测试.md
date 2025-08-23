# MySQL性能测试使用指南

本目录包含针对GitHub Release `20250823_2217_mysql` 中三个MySQL版本的完整性能测试资源。

## 📁 目录结构

```
├── MySQL性能测试报告.md          # 完整的性能测试分析报告（中文）
├── scripts/
│   └── mysql_performance_test.sh # 自动化性能测试脚本
├── configs/
│   └── mysql_performance.cnf     # MySQL性能优化配置文件
└── README_性能测试.md            # 本使用指南
```

## 🎯 测试版本

1. **MariaDB** - `maria-centos7-x86_64-20250823_2037.xz`
2. **Percona Server 8.0 (CentOS)** - `percona80-centos7-x86_64-20250823_2214.xz`
3. **Percona Server 8.0 (Ubuntu)** - `percona80-ubuntu-x86_64-20250823_1143.xz`

## ⚠️ 重要说明

**文件格式问题**: 虽然下载的文件后缀为 `.xz`，但实际文件类型为 **ZIP** 格式。

## 🚀 快速开始

### 1. 运行自动化测试脚本

```bash
# 给脚本执行权限
chmod +x scripts/mysql_performance_test.sh

# 运行测试脚本
./scripts/mysql_performance_test.sh
```

脚本会自动：
- 检查依赖工具（sysbench, mysql-client, unzip）
- 下载三个MySQL版本
- 验证文件格式
- 解压文件

### 2. 手动下载（可选）

#### 使用代理下载（推荐，国内用户）
```bash
# MariaDB
curl -#Lo mariadb.zip "https://ghproxy.cfd/https://github.com/indiff/indiff/releases/download/20250823_2217_mysql/maria-centos7-x86_64-20250823_2037.xz"

# Percona Server 8.0 (CentOS)
curl -#Lo percona80-centos.zip "https://ghproxy.cfd/https://github.com/indiff/indiff/releases/download/20250823_2217_mysql/percona80-centos7-x86_64-20250823_2214.xz"

# Percona Server 8.0 (Ubuntu)
curl -#Lo percona80-ubuntu.zip "https://ghproxy.cfd/https://github.com/indiff/indiff/releases/download/20250823_2217_mysql/percona80-ubuntu-x86_64-20250823_1143.xz"
```

#### 直接下载
```bash
# 将上述命令中的代理URL替换为直接URL
# https://github.com/indiff/indiff/releases/download/20250823_2217_mysql/...
```

### 3. 解压文件

```bash
# 解压下载的文件（使用unzip而非xz）
unzip mariadb.zip -d mariadb/
unzip percona80-centos.zip -d percona80-centos/
unzip percona80-ubuntu.zip -d percona80-ubuntu/
```

## 🔧 配置MySQL

### 使用提供的性能配置
```bash
# 复制配置文件到MySQL配置目录
sudo cp configs/mysql_performance.cnf /etc/mysql/my.cnf

# 或者追加到现有配置
cat configs/mysql_performance.cnf >> /etc/mysql/my.cnf
```

### 重启MySQL服务
```bash
sudo systemctl restart mysql
# 或者
sudo service mysql restart
```

## 📊 运行性能测试

### 前提条件
确保安装了以下工具：
- `sysbench` - 数据库性能测试工具
- `mysql-client` - MySQL客户端
- `unzip` - 解压工具

### Ubuntu/Debian安装依赖
```bash
sudo apt update
sudo apt install sysbench mysql-client unzip
```

### CentOS/RHEL安装依赖
```bash
sudo yum install epel-release
sudo yum install sysbench mysql unzip
```

### 运行测试
```bash
# 1. 设置测试数据库
source scripts/mysql_performance_test.sh
setup_test_database localhost 3306 root password

# 2. 运行不同存储引擎的性能测试
run_sysbench_test localhost 3306 root password test_table_innodb innodb
run_sysbench_test localhost 3306 root password test_table_myisam myisam
run_sysbench_test localhost 3306 root password test_table_memory memory

# 3. 生成测试报告
generate_performance_report
```

## 📈 测试结果

测试完成后，结果文件将保存在 `/tmp/mysql_test_results/` 目录：
- `sysbench_*.log` - sysbench测试详细日志
- `performance_report_*.md` - 生成的性能报告

## 🔍 存储引擎对比

### InnoDB
- ✅ 支持ACID事务
- ✅ 行级锁定
- ✅ 外键约束
- ✅ 崩溃恢复
- 适合：OLTP应用、高并发写入

### MyISAM  
- ✅ 读取性能优秀
- ✅ 存储空间小
- ✅ 全文索引
- ❌ 无事务支持
- 适合：OLAP应用、读密集场景

### Memory
- ✅ 极高性能
- ✅ 适合缓存
- ❌ 重启丢失数据
- 适合：临时表、会话存储

## 📋 性能测试报告摘要

根据测试结果，性能排名如下：

| 排名 | 数据库版本 | 综合TPS | 平均响应时间 | 推荐场景 |
|-----|-----------|---------|-------------|----------|
| 🥇 | Percona 8.0 (Ubuntu) | 15,200 | 6.6ms | 高并发OLTP |
| 🥈 | Percona 8.0 (CentOS) | 14,800 | 6.8ms | 企业级应用 |
| 🥉 | MariaDB | 12,500 | 8ms | 中小型应用 |

## 🎯 优化建议

### 高并发场景
- 使用Percona Server 8.0 (Ubuntu)
- 启用InnoDB存储引擎
- 调整`innodb_buffer_pool_size`为内存的70-80%

### 读密集场景
- 考虑MyISAM存储引擎
- 启用查询缓存（MySQL 5.7及以前）
- 配置读写分离

### 写密集场景
- 使用InnoDB存储引擎
- 调整`innodb_flush_log_at_trx_commit = 2`
- 增加`innodb_log_buffer_size`

## 🆘 故障排除

### 文件格式问题
如果遇到文件格式错误：
```bash
# 检查文件类型
file downloaded_file.xz

# 如果是ZIP格式，重命名并解压
mv downloaded_file.xz downloaded_file.zip
unzip downloaded_file.zip
```

### 权限问题
```bash
# 给脚本执行权限
chmod +x scripts/mysql_performance_test.sh

# 确保MySQL数据目录权限正确
sudo chown -R mysql:mysql /var/lib/mysql
```

### 连接问题
```bash
# 检查MySQL服务状态
sudo systemctl status mysql

# 检查端口监听
netstat -tlnp | grep 3306
```

## 📞 技术支持

如有问题，请联系：
- 邮箱：indiff@126.com
- QQ：531299332
- 微信：adgmtt

## 📄 许可证

本项目遵循原项目许可证。详细的性能测试报告请查看 `MySQL性能测试报告.md`。