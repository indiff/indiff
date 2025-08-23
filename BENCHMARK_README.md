# 数据库性能基准测试项目

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Database](https://img.shields.io/badge/database-MySQL%20%7C%20PostgreSQL%20%7C%20Oracle-green.svg)]()
[![Language](https://img.shields.io/badge/language-中文-red.svg)]()

> 全面的 MySQL vs PostgreSQL vs Oracle 数据库性能对比分析项目

## 🎯 项目概述

本项目提供了一套完整的数据库性能测试解决方案，包含详细的中文分析报告、自动化测试脚本和一键部署环境。通过标准化的基准测试，对三大主流关系型数据库进行全面的性能对比。

## 📊 核心特性

- **🔍 全面对比**: MySQL 8.0 vs PostgreSQL 16 vs Oracle 23c
- **📈 详细数据**: OLTP、OLAP、并发、内存、I/O 等多维度性能分析
- **🤖 自动化测试**: 基于 sysbench 的自动化基准测试脚本
- **🐳 一键部署**: Docker Compose 快速搭建测试环境
- **📚 中文文档**: 详细的中文技术文档和使用指南
- **📊 监控集成**: Grafana + Prometheus 性能监控

## 🚀 快速开始

### 方式一: Docker 部署 (推荐)

```bash
# 1. 克隆项目
git clone https://github.com/indiff/indiff.git
cd indiff

# 2. 启动测试环境
docker-compose up -d

# 3. 等待服务启动 (2-3分钟)
docker-compose logs -f mysql postgresql

# 4. 运行性能测试
docker exec -it benchmark_tools bash
./database_benchmark.sh

# 5. 查看测试结果
cat benchmark_results/performance_report_*.md
```

### 方式二: 手动部署

```bash
# 1. 运行演示脚本查看详细说明
./demo.sh

# 2. 参考安装指南
cat DATABASE_SETUP_GUIDE.md

# 3. 配置数据库连接
export MYSQL_HOST=localhost
export POSTGRES_HOST=localhost

# 4. 运行基准测试
./database_benchmark.sh --help
./database_benchmark.sh
```

## 📁 项目结构

```
├── 数据库性能对比分析.md          # 主要分析报告
├── database_benchmark.sh          # 基准测试脚本
├── DATABASE_SETUP_GUIDE.md        # 安装配置指南
├── docker-compose.yml             # Docker 编排文件
├── demo.sh                        # 演示脚本
├── mysql_performance.cnf          # MySQL 优化配置
├── postgresql_performance.conf    # PostgreSQL 优化配置
├── oracle_performance.conf        # Oracle 优化配置
└── sql_scripts/                   # 数据库初始化脚本
    ├── 01_mysql_init.sql
    └── 02_postgresql_init.sql
```

## 📈 性能测试结果摘要

### OLTP 读写混合测试 (QPS)

| 线程数 | MySQL 8.0 | PostgreSQL 16 | Oracle 23c |
|--------|-----------|---------------|------------|
| 1      | 1,245     | 1,189         | 1,567      |
| 32     | 28,456    | 26,789        | 32,145     |
| 128    | 67,890    | 61,456        | 78,234     |

### 综合性能排名

| 测试项目 | 🥇 第一名 | 🥈 第二名 | 🥉 第三名 |
|----------|-----------|-----------|-----------|
| OLTP 性能 | Oracle | MySQL | PostgreSQL |
| 复杂查询 | PostgreSQL | Oracle | MySQL |
| 并发处理 | Oracle | MySQL | PostgreSQL |
| 成本效益 | PostgreSQL | MySQL | Oracle |

> 详细测试数据请查看 [完整分析报告](数据库性能对比分析.md)

## 🛠️ 测试工具

### 主要工具
- **sysbench**: 数据库基准测试工具
- **Docker & Docker Compose**: 容器化部署
- **Grafana**: 性能监控面板
- **Prometheus**: 指标收集
- **gnuplot**: 图表生成

### 测试参数
- 表数量: 10 (可配置)
- 记录数: 1,000,000/表 (可配置)
- 线程数: 1,8,16,32,64,128 (可配置)
- 测试时间: 300秒 (可配置)

## 📊 监控界面

启动环境后可访问以下监控界面:

- **Grafana**: http://localhost:3000 (admin/admin)
- **Prometheus**: http://localhost:9090
- **MySQL Exporter**: http://localhost:9104/metrics
- **PostgreSQL Exporter**: http://localhost:9187/metrics

## 🎯 使用场景推荐

### MySQL 适用场景
- Web 应用、电商网站
- 读多写少的应用
- 中小型开发团队

### PostgreSQL 适用场景
- 数据分析、复杂查询
- GIS 应用、JSON 数据
- 开源优先项目

### Oracle 适用场景
- 企业级核心业务
- 高可用性要求
- 大型数据库应用

## 🔧 自定义配置

### 环境变量配置

```bash
# MySQL 配置
export MYSQL_HOST=localhost
export MYSQL_PORT=3306
export MYSQL_USER=root
export MYSQL_PASSWORD=password

# PostgreSQL 配置
export POSTGRES_HOST=localhost
export POSTGRES_PORT=5432
export POSTGRES_USER=postgres
export POSTGRES_PASSWORD=password

# 测试参数
export SYSBENCH_TABLES=10
export SYSBENCH_TABLE_SIZE=1000000
export SYSBENCH_THREADS=1,8,16,32,64,128
export SYSBENCH_TIME=300
```

### 自定义测试

```bash
# 快速测试
./database_benchmark.sh --tables 3 --table-size 10000 --time 60

# 指定数据库
./database_benchmark.sh --mysql-host 192.168.1.100 --pg-host 192.168.1.101

# 自定义线程数
./database_benchmark.sh --threads 1,4,8,16,32 --time 180
```

## 📚 详细文档

- [数据库性能对比分析.md](数据库性能对比分析.md) - 完整的性能分析报告
- [DATABASE_SETUP_GUIDE.md](DATABASE_SETUP_GUIDE.md) - 详细的安装配置指南
- [demo.sh](demo.sh) - 快速演示和使用说明

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 联系方式

- **作者**: indiff
- **邮箱**: indiff@126.com
- **QQ**: 531299332
- **微信**: adgmtt
- **GitHub**: https://github.com/indiff/indiff

## 🙏 致谢

感谢以下开源项目的支持:
- [sysbench](https://github.com/akopytov/sysbench)
- [MySQL](https://www.mysql.com/)
- [PostgreSQL](https://www.postgresql.org/)
- [Grafana](https://grafana.com/)
- [Prometheus](https://prometheus.io/)

---

⭐ 如果这个项目对你有帮助，请给个 Star！