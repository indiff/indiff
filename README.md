
<a href="https://github.com/indiff?tab=repositories">
  <img width="50%" align="right" src="https://github-readme-stats.vercel.app/api?username=indiff&count_private=true&show_icons=true" />
</a>

<a href="https://profile.codersrank.io/user/indiff/">
  <img width="50%" align="right" src="https://cr-skills-chart-widget.azurewebsites.net/api/api?username=indiff&skills=Java,CSS,JSON,HTML,JavaScript,Kotlin,Less,PHP,Python,SCSS,Shell,TypeScript,Vue" />
</a>


I'm A software developer .

👀 My Projects:
- [qttabbar](https://github.com/indiff/qttabbar)
- [DBCHM](https://github.com/indiff/DBCHM)
- [Jutils](https://github.com/indiff/Jutils_Plugin)

## 🚀 MySQL vs Percona vs MariaDB 三数据库性能测试框架

本仓库包含了一个完整的三数据库性能对比测试框架，支持 MySQL 8.0、Percona Server 8.0 和 MariaDB 的自动化并发测试，包含多种存储引擎的性能对比分析。

### ✨ 主要特性

- 📊 **三数据库全面对比**: MySQL 8.0、Percona Server 8.0、MariaDB latest 
- 🗄️ **多存储引擎支持**: InnoDB、RocksDB、ColumnStore 存储引擎对比
- 🔧 **多种测试场景**: OLTP 读写混合、只读、只写、插入及分析查询测试
- 🏗️ **预编译 Percona 集成**: 使用预编译的 CentOS7 版本 Percona Server (包含 RocksDB)
- 🐳 **容器化环境**: 基于 Docker Compose 确保测试环境一致性
- 📈 **增强的报告系统**: 生成包含 TPS、延迟、存储引擎对比等详细指标
- ⚡ **自动化测试**: GitHub Actions 支持定时和手动触发
- 📊 **全面监控**: Prometheus + Grafana 三数据库实时性能监控

### 🎯 支持的数据库和存储引擎

| 数据库 | 版本 | 支持的存储引擎 | 主要特点 |
|--------|------|----------------|----------|
| MySQL | 8.0 | InnoDB | 业界标准，通用 OLTP 优化 |
| Percona Server | 8.0 | InnoDB, RocksDB | 高性能 MySQL 分支，写优化 |
| MariaDB | latest | InnoDB, ColumnStore | MySQL 分支，分析查询优化 |

### 🏃‍♂️ 快速开始

\`\`\`bash
# 克隆仓库
git clone https://github.com/indiff/indiff.git
cd indiff

# 运行快速三数据库测试 (1分钟)
./quick-start.sh --quick

# 运行标准三数据库测试 (5分钟)
./quick-start.sh

# 运行传统双数据库测试 (MySQL vs Percona)
./quick-start.sh --legacy

# 启动三数据库监控环境
./quick-start.sh --monitor
\`\`\`

### 📋 测试报告示例

测试完成后会生成详细的对比报告，包括：

| 测试场景 | MySQL TPS | Percona TPS | 性能提升 | MySQL 延迟 | Percona 延迟 |
|----------|-----------|-------------|----------|------------|--------------|
| 读写混合 | 1,234.56  | 1,456.78    | +18.0%   | 25.6ms     | 21.8ms       |
| 只读测试 | 2,345.67  | 2,678.90    | +14.2%   | 13.7ms     | 11.9ms       |

### 📚 详细文档

- [性能测试完整指南](docs/PERFORMANCE_TESTING.md)
- [Docker Compose 使用说明](docker-compose.yml)
- [测试脚本参数说明](scripts/mysql-performance-test.sh)


🌱 I’m currently learning:

&ensp;&ensp;&ensp;![Java](https://img.shields.io/badge/-Java-007396?style=flat-square&logo=Java&logoColor=fff) ![TypeScript](https://img.shields.io/badge/-TypeScript-007ACC?style=flat-square&logo=TypeScript&logoColor=fff) ![JavaScript](https://img.shields.io/badge/-JavaScript-F7DF1E?style=flat-square&logo=JavaScript&logoColor=000)

🎉 I’m interested in things related to:

&ensp;&ensp;&ensp;![Spring](https://img.shields.io/badge/-Spring-6DB33F?style=flat-square&logo=Spring&logoColor=fff) ![React](https://img.shields.io/badge/-React-61DAFB?style=flat-square&logo=React&logoColor=000) ![Vue](https://img.shields.io/badge/-Vue-4FC08D?style=flat-square&logo=Vue.js&logoColor=fff) ![Docker](https://img.shields.io/badge/-Docker-2496ED?style=flat-square&logo=Docker&logoColor=fff) ![Python](https://img.shields.io/badge/-Python-2496ED?style=flat-square&logo=Python&logoColor=fff) ![Charp](https://img.shields.io/badge/-Charp-2496ED?style=flat-square&logo=Charp&logoColor=fff)

⚡ I like to use these  tools:

&ensp;&ensp;&ensp;![IntelliJ IDEA](https://img.shields.io/badge/-IntelliJ%20IDEA-000000?style=flat-square&logo=IntelliJ%20IDEA&logoColor=fff) ![Visual Studio Code](https://img.shields.io/badge/-Visual%20Studio%20Code-007ACC?style=flat-square&logo=Visual%20Studio%20Code&logoColor=fff) ![Microsoft Edge](https://img.shields.io/badge/-Microsoft%20Edge-0078D7?style=flat-square&logo=Microsoft%20Edge&logoColor=fff) ![Firefox](https://img.shields.io/badge/-Firefox-FF7139?style=flat-square&logo=Firefox&logoColor=fff) ![Github](https://img.shields.io/badge/-Github-181717?style=flat-square&logo=Github&logoColor=fff) ![Github Actions](https://img.shields.io/badge/-Github%20Actions-2088FF?style=flat-square&logo=Github%20Actions&logoColor=fff) ![Windows](https://img.shields.io/badge/-Windows-0078D6?style=flat-square&logo=Windows&logoColor=fff) ![Ubuntu](https://img.shields.io/badge/-Ubuntu-E95420?style=flat-square&logo=Ubuntu&logoColor=fff) ![Arch Linux](https://img.shields.io/badge/-Arch%20Linux-1793D1?style=flat-square&logo=Arch%20Linux&logoColor=fff) ![Android](https://img.shields.io/badge/-Android-3DDC84?style=flat-square&logo=Android&logoColor=fff)

📫 How to reach me: indiff@126.com
- qq: 531299332
- wechat: adgmtt


