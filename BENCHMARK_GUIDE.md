# 数据库性能基准测试工具 (Database Performance Benchmark Tool)

## 简介 (Introduction)

此工具用于对比使用 indiff 项目编译的自定义数据库与标准 Java 数据源的性能。

This tool is designed to compare the performance of custom-built databases compiled by the indiff project against standard Java data sources.

## 快速开始 (Quick Start)

### 1. 构建项目 (Build the Project)

```bash
cd performance-benchmark
mvn clean package
```

### 2. 配置数据库连接 (Configure Database Connections)

复制示例配置文件并编辑:
Copy the example configuration file and edit it:

```bash
cp benchmark.properties.example benchmark.properties
vim benchmark.properties
```

### 3. 运行测试 (Run the Test)

```bash
./run-benchmark.sh benchmark.properties
```

或者直接运行 JAR:
Or run the JAR directly:

```bash
java -jar target/db-performance-benchmark-1.0.0-jar-with-dependencies.jar benchmark.properties
```

## 功能特性 (Features)

- ✅ 支持多种数据库: MySQL, PostgreSQL, MariaDB
- ✅ 8 种性能测试场景
- ✅ 自动生成多格式报告 (控制台、JSON、Markdown)
- ✅ 使用 HikariCP 连接池优化
- ✅ 详细的性能指标统计

## 测试场景 (Test Scenarios)

1. **连接性能** - 测试数据库连接建立速度
2. **简单查询** - 单行查询性能
3. **表创建** - DDL 操作性能
4. **单条插入** - 单行插入性能
5. **批量插入** - 批量数据插入性能
6. **范围查询** - 多行查询性能
7. **更新操作** - 数据更新性能
8. **删除操作** - 数据删除性能

## 报告输出 (Report Output)

测试完成后会生成:
After testing, the following will be generated:

- 控制台实时报告 (Console report)
- JSON 格式报告 (JSON format report)
- Markdown 格式报告 (Markdown format report)
- 日志文件 (Log file)

## 示例配置 (Example Configuration)

```properties
# 自定义编译的 MySQL
db.1.name=Custom MySQL (indiff build)
db.1.type=mysql
db.1.url=jdbc:mysql://localhost:3306/benchmark
db.1.username=root
db.1.password=password

# 标准 MySQL (用于对比)
db.2.name=Standard MySQL
db.2.type=mysql
db.2.url=jdbc:mysql://localhost:3307/benchmark
db.2.username=root
db.2.password=password
```

## 性能优化说明 (Performance Optimization Notes)

使用 indiff 项目编译的数据库具有以下优化:

Databases compiled using the indiff project have the following optimizations:

1. **编译器优化 (Compiler Optimizations)**
   - `-O2` 优化级别
   - `-march=native` CPU 架构优化
   - Link-Time Optimization (LTO)

2. **功能精简 (Feature Streamlining)**
   - 禁用不必要的 Performance Schema 特性
   - 移除不常用的存储引擎

3. **依赖优化 (Dependency Optimization)**
   - 使用系统优化的库
   - 高效的内存分配器 (jemalloc)

## 查看示例报告 (View Sample Report)

查看示例性能报告:
View the sample performance report:

```bash
cat performance-benchmark/SAMPLE_REPORT.md
```

## 详细文档 (Detailed Documentation)

更多详细信息请参阅:
For more details, please refer to:

```bash
cat performance-benchmark/README.md
```

## 系统要求 (System Requirements)

- Java 11+
- Maven 3.6+
- 运行中的数据库实例 (至少一个)

## 注意事项 (Important Notes)

1. 测试会创建临时表，确保有足够权限
2. 建议在专用测试环境运行
3. 性能结果受硬件和配置影响
4. 多次运行可获得更准确结果

## 贡献 (Contributing)

欢迎提交问题和改进建议!
Issues and improvement suggestions are welcome!

## 许可证 (License)

遵循 indiff/indiff 仓库许可证
Follows the indiff/indiff repository license
