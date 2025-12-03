# Database Performance Benchmark

## 概述 (Overview)

这是一个数据库性能基准测试工具，用于比较使用当前项目编译的自定义数据库与标准 Java 数据源的性能。

This is a database performance benchmarking tool designed to compare the performance of custom-built databases (compiled by this project) against standard Java data sources.

## 功能特性 (Features)

- 支持多种数据库：MySQL、PostgreSQL、MariaDB
- 多维度性能测试：
  - 连接性能
  - 简单查询
  - 表创建
  - 单条插入
  - 批量插入
  - 范围查询
  - 更新操作
  - 删除操作
- 自动生成性能报告（控制台、JSON、Markdown 格式）
- 使用 HikariCP 连接池优化性能
- 详细的性能指标：平均时间、最小时间、最大时间、吞吐量

## 构建项目 (Build)

```bash
cd performance-benchmark
mvn clean package
```

这将生成两个 JAR 文件：
- `db-performance-benchmark-1.0.0.jar` - 基础 JAR
- `db-performance-benchmark-1.0.0-jar-with-dependencies.jar` - 包含所有依赖的可执行 JAR

## 配置 (Configuration)

### 创建配置文件

复制示例配置文件并根据您的环境修改：

```bash
cp benchmark.properties.example benchmark.properties
```

### 配置文件格式

```properties
# 数据库 1
db.1.name=Custom MySQL (indiff build)
db.1.type=mysql
db.1.url=jdbc:mysql://localhost:3306/benchmark
db.1.username=root
db.1.password=password

# 数据库 2
db.2.name=Standard MySQL
db.2.type=mysql
db.2.url=jdbc:mysql://localhost:3307/benchmark
db.2.username=root
db.2.password=password
```

支持的数据库类型：
- `mysql` - MySQL 数据库
- `postgresql` (或 `postgres`, `pg`) - PostgreSQL 数据库
- `mariadb` - MariaDB 数据库

## 使用方法 (Usage)

### 准备数据库

在运行基准测试之前，确保目标数据库已经启动并创建了测试数据库：

```sql
-- MySQL/MariaDB
CREATE DATABASE benchmark;

-- PostgreSQL
CREATE DATABASE benchmark;
```

### 运行基准测试

使用配置文件运行：

```bash
java -jar target/db-performance-benchmark-1.0.0-jar-with-dependencies.jar benchmark.properties
```

使用默认配置运行（仅用于测试）：

```bash
java -jar target/db-performance-benchmark-1.0.0-jar-with-dependencies.jar
```

## 性能测试项目 (Benchmark Tests)

### 1. 连接性能 (Connection Performance)
- 测试次数：100 次
- 测试内容：创建和关闭数据库连接
- 指标：连接建立的平均时间

### 2. 简单查询 (Simple Select)
- 测试次数：1000 次
- 测试内容：单行查询
- 指标：查询执行时间

### 3. 表创建 (Create Table)
- 测试次数：10 次
- 测试内容：创建和删除表
- 指标：DDL 操作性能

### 4. 单条插入 (Single Insert)
- 测试次数：1000 次
- 测试内容：单条记录插入
- 指标：插入操作性能

### 5. 批量插入 (Batch Insert)
- 测试次数：10 批
- 批次大小：100 条/批
- 测试内容：批量插入记录
- 指标：批量操作性能

### 6. 范围查询 (Select Range)
- 测试次数：100 次
- 数据集：1000 条记录
- 测试内容：范围查询（每次 10 条）
- 指标：范围查询性能

### 7. 更新操作 (Update)
- 测试次数：100 次
- 测试内容：单条记录更新
- 指标：更新操作性能

### 8. 删除操作 (Delete)
- 测试次数：100 次
- 测试内容：单条记录删除
- 指标：删除操作性能

## 报告输出 (Report Output)

基准测试完成后，将生成以下报告：

1. **控制台报告** - 实时显示在终端
2. **JSON 报告** - `benchmark-results-{timestamp}.json`
3. **Markdown 报告** - `benchmark-report-{timestamp}.md`
4. **日志文件** - `benchmark.log`

### 报告内容

- 每个数据库的详细测试结果
- 性能指标（平均值、最小值、最大值、总时间、吞吐量）
- 不同数据库之间的性能对比表

## 性能对比示例 (Performance Comparison Example)

```
================================================================================
Database Performance Benchmark Report
================================================================================

--------------------------------------------------------------------------------
Database: Custom MySQL (indiff build) (mysql)
--------------------------------------------------------------------------------
Test Name                   Avg (ms)   Min (ms)   Max (ms) Total (ms)  Throughput/s     Status
--------------------------------------------------------------------------------
Connection Performance             5          3         12        500          20000    SUCCESS
Simple Select                      2          1          5       2000         500000    SUCCESS
Create Table                      15         10         25        150             66    SUCCESS
Single Insert                      3          2          8       3000         333333    SUCCESS
Batch Insert                      50         45         60        500            200    SUCCESS
...
```

## 系统要求 (Requirements)

- Java 11 或更高版本
- Maven 3.6 或更高版本
- 至少一个运行中的数据库实例

## 依赖项 (Dependencies)

- MySQL Connector/J 8.0.33
- PostgreSQL JDBC Driver 42.7.3
- MariaDB Java Client 3.3.3
- HikariCP 5.1.0
- Gson 2.10.1
- Logback 1.4.14

## 注意事项 (Notes)

1. 基准测试将创建和删除临时表（以 `bench_` 开头）
2. 确保测试数据库有足够的权限
3. 建议在专用的测试环境中运行基准测试
4. 多次运行可以获得更准确的结果
5. 性能结果受硬件、网络和数据库配置影响

## 故障排除 (Troubleshooting)

### 连接失败

确保：
- 数据库服务正在运行
- 连接字符串正确
- 用户名和密码正确
- 防火墙允许连接

### 权限错误

确保数据库用户有以下权限：
- CREATE
- DROP
- INSERT
- UPDATE
- DELETE
- SELECT

### 内存不足

如果遇到内存问题，可以增加 JVM 堆内存：

```bash
java -Xmx2g -jar target/db-performance-benchmark-1.0.0-jar-with-dependencies.jar benchmark.properties
```

## 贡献 (Contributing)

欢迎提交问题报告和改进建议！

## 许可证 (License)

本项目遵循与 indiff/indiff 仓库相同的许可证。
