# 数据库性能测试环境搭建指南

## 快速开始

### 方式一: 使用 Docker Compose (推荐)

1. **克隆仓库**
   ```bash
   git clone https://github.com/indiff/indiff.git
   cd indiff
   ```

2. **启动测试环境**
   ```bash
   # 启动所有数据库服务
   docker-compose up -d
   
   # 查看服务状态
   docker-compose ps
   ```

3. **等待服务启动完成**
   ```bash
   # 检查服务健康状态
   docker-compose logs mysql
   docker-compose logs postgresql
   docker-compose logs oracle
   ```

4. **运行性能测试**
   ```bash
   # 进入测试容器
   docker exec -it benchmark_tools bash
   
   # 运行基准测试
   ./database_benchmark.sh
   ```

5. **查看结果**
   ```bash
   # 测试结果保存在 benchmark_results 目录
   ls -la benchmark_results/
   
   # 查看性能报告
   cat benchmark_results/performance_report_*.md
   ```

### 方式二: 手动安装配置

#### 系统要求

- **操作系统**: CentOS 7/8, Ubuntu 18.04+, RHEL 7/8
- **内存**: 最少 8GB，推荐 16GB+
- **存储**: 至少 100GB 可用空间
- **CPU**: 4核心+，推荐 8核心+

#### 安装数据库

**安装 MySQL 8.0**
```bash
# CentOS/RHEL
sudo yum install -y mysql-server
sudo systemctl start mysqld
sudo systemctl enable mysqld

# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql

# 配置 MySQL
sudo cp mysql_performance.cnf /etc/mysql/conf.d/
sudo systemctl restart mysql
```

**安装 PostgreSQL 16**
```bash
# CentOS/RHEL
sudo yum install -y postgresql-server postgresql-contrib
sudo postgresql-setup initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Ubuntu/Debian
sudo apt-get install -y postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# 配置 PostgreSQL
sudo cp postgresql_performance.conf /etc/postgresql/16/main/
sudo systemctl restart postgresql
```

**安装 Oracle Database 23c**
```bash
# 下载 Oracle Database 23c Free
wget https://download.oracle.com/otn-pub/otn_software/db-free/oracle-database-free-23c-1.0-1.el8.x86_64.rpm

# 安装 Oracle
sudo yum install -y oracle-database-free-23c-1.0-1.el8.x86_64.rpm

# 配置 Oracle
sudo /etc/init.d/oracle-free-23c configure
```

#### 安装测试工具

```bash
# 安装 sysbench
# CentOS/RHEL
sudo yum install -y epel-release
sudo yum install -y sysbench

# Ubuntu/Debian
sudo apt-get install -y sysbench

# 安装数据库客户端
sudo yum install -y mysql postgresql oracle-instantclient
# 或
sudo apt-get install -y mysql-client postgresql-client

# 安装其他工具
sudo yum install -y gnuplot git
```

#### 配置数据库连接

**MySQL 配置**
```bash
# 创建测试用户
mysql -uroot -p -e "
CREATE USER 'benchmark'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON *.* TO 'benchmark'@'%';
FLUSH PRIVILEGES;
"
```

**PostgreSQL 配置**
```bash
# 创建测试用户
sudo -u postgres psql -c "
CREATE USER benchmark WITH PASSWORD 'password';
ALTER USER benchmark CREATEDB;
"
```

**Oracle 配置**
```bash
# 连接到 Oracle 并创建测试用户
sqlplus system/password@localhost:1521/FREE
CREATE USER benchmark IDENTIFIED BY password;
GRANT CONNECT, RESOURCE, DBA TO benchmark;
EXIT;
```

## 性能测试参数配置

### 环境变量配置

创建 `.env` 文件来配置数据库连接参数：

```bash
# MySQL 配置
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=benchmark
MYSQL_PASSWORD=password
MYSQL_DATABASE=benchmark_test

# PostgreSQL 配置
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=benchmark
POSTGRES_PASSWORD=password
POSTGRES_DATABASE=benchmark_test

# Oracle 配置
ORACLE_HOST=localhost
ORACLE_PORT=1521
ORACLE_USER=benchmark
ORACLE_PASSWORD=password
ORACLE_SID=FREE

# 测试参数配置
SYSBENCH_TABLES=10
SYSBENCH_TABLE_SIZE=1000000
SYSBENCH_THREADS=1,8,16,32,64,128
SYSBENCH_TIME=300
```

### 运行基准测试

```bash
# 使用默认配置运行测试
./database_benchmark.sh

# 使用自定义参数运行测试
./database_benchmark.sh \
  --mysql-host 192.168.1.100 \
  --pg-host 192.168.1.101 \
  --tables 5 \
  --table-size 500000 \
  --threads 1,4,8,16,32 \
  --time 180

# 查看帮助信息
./database_benchmark.sh --help
```

## 测试结果分析

### 结果文件说明

测试完成后，会在 `benchmark_results` 目录下生成以下文件：

- `mysql_oltp_read_write_*.txt` - MySQL 读写混合测试结果
- `postgresql_oltp_read_write_*.txt` - PostgreSQL 读写混合测试结果
- `mysql_oltp_read_only_*.txt` - MySQL 只读测试结果
- `postgresql_oltp_read_only_*.txt` - PostgreSQL 只读测试结果
- `performance_report_*.md` - 综合性能报告

### 性能指标解读

**关键性能指标 (KPI)**

1. **QPS (Queries Per Second)** - 每秒查询数
   - 衡量数据库的吞吐能力
   - 数值越高表示性能越好

2. **TPS (Transactions Per Second)** - 每秒事务数
   - 衡量数据库的事务处理能力
   - 对于 OLTP 应用非常重要

3. **响应时间 (Response Time)**
   - 95th percentile - 95% 的请求响应时间
   - Average - 平均响应时间
   - 数值越低表示性能越好

4. **CPU 使用率** - 处理器利用率
   - 反映数据库的 CPU 效率
   - 过高可能表示 CPU 瓶颈

5. **内存使用率** - 内存利用率
   - 反映缓存命中率和内存效率
   - 合理使用内存可以提高性能

### 生成性能图表

```bash
# 安装 gnuplot (如果未安装)
sudo yum install gnuplot
# 或
sudo apt-get install gnuplot

# 生成性能对比图表
cd benchmark_results

# 提取 QPS 数据
grep "queries:" mysql_oltp_read_write_*.txt | awk '{print $4}' > mysql_qps.dat
grep "queries:" postgresql_oltp_read_write_*.txt | awk '{print $4}' > postgresql_qps.dat

# 生成 QPS 对比图
gnuplot -e "
set terminal png size 800,600;
set output 'qps_comparison.png';
set title 'Database QPS Performance Comparison';
set xlabel 'Thread Count';
set ylabel 'Queries Per Second';
set grid;
plot 'mysql_qps.dat' with linespoints title 'MySQL', \
     'postgresql_qps.dat' with linespoints title 'PostgreSQL'
"
```

## 监控和调优

### 实时监控

如果使用 Docker Compose 方式，可以访问监控界面：

- **Grafana 监控面板**: http://localhost:3000
  - 用户名: admin
  - 密码: admin

- **Prometheus 指标**: http://localhost:9090

### 性能调优建议

**MySQL 调优要点**

1. 调整 InnoDB 缓冲池大小
   ```sql
   SET GLOBAL innodb_buffer_pool_size = 32*1024*1024*1024; -- 32GB
   ```

2. 优化查询缓存（MySQL 5.7 及以下）
   ```sql
   SET GLOBAL query_cache_size = 256*1024*1024; -- 256MB
   ```

3. 调整连接数
   ```sql
   SET GLOBAL max_connections = 1000;
   ```

**PostgreSQL 调优要点**

1. 调整共享缓冲区
   ```sql
   ALTER SYSTEM SET shared_buffers = '16GB';
   ```

2. 优化工作内存
   ```sql
   ALTER SYSTEM SET work_mem = '256MB';
   ```

3. 调整检查点参数
   ```sql
   ALTER SYSTEM SET checkpoint_completion_target = 0.9;
   ```

**Oracle 调优要点**

1. 调整 SGA 大小
   ```sql
   ALTER SYSTEM SET sga_target = 32G SCOPE=SPFILE;
   ```

2. 优化 PGA
   ```sql
   ALTER SYSTEM SET pga_aggregate_target = 16G SCOPE=SPFILE;
   ```

3. 配置并行执行
   ```sql
   ALTER SYSTEM SET parallel_max_servers = 64;
   ```

## 故障排除

### 常见问题解决

**问题 1: sysbench 连接数据库失败**
```bash
# 检查数据库服务状态
systemctl status mysql
systemctl status postgresql

# 检查端口是否开放
netstat -tulnp | grep 3306
netstat -tulnp | grep 5432

# 检查防火墙设置
sudo firewall-cmd --list-ports
sudo ufw status
```

**问题 2: 内存不足**
```bash
# 检查系统内存
free -h

# 调整数据库内存配置
# 编辑对应的配置文件，减少内存使用量
```

**问题 3: 权限问题**
```bash
# 检查文件权限
ls -la database_benchmark.sh
chmod +x database_benchmark.sh

# 检查数据库用户权限
mysql -u benchmark -p -e "SHOW GRANTS;"
```

### 获取帮助

- 查看详细日志: `cat benchmark_logs/benchmark_*.log`
- 检查数据库错误日志
- 参考 [数据库性能对比分析.md](数据库性能对比分析.md) 了解更多详细信息

## 联系方式

如有问题或建议，请联系：
- 邮箱: indiff@126.com
- QQ: 531299332
- 微信: adgmtt