# MySQL & RocksDB 预编译包构建系统

本仓库包含了构建 MySQL、RocksDB 和 MariaDB ColumnStore 预编译包的 GitHub Actions 工作流。

## 🚀 功能特性

### 核心功能
- **自动错误修复**: 编译失败时自动检测并修复常见问题，最多重试3次
- **最新依赖管理**: 使用 vcpkg 管理所有依赖库，确保使用最新版本
- **多平台支持**: 优先支持 CentOS 7，同时支持 Ubuntu
- **全面覆盖**: MySQL 8.4、Percona Server 8.0、MariaDB 11.5 + ColumnStore 引擎

### 构建目标
1. **MySQL 8.4** with RocksDB Storage Engine
2. **Percona Server 8.0** with RocksDB Storage Engine  
3. **MariaDB 11.5** with ColumnStore + RocksDB Storage Engines
4. **Standalone RocksDB** Library (多平台)

## 📋 工作流说明

### 1. `enhanced-mysql-build.yml` - 增强版 MySQL 构建
**用途**: 最全面的构建工作流，包含所有数据库系统

**特性**:
- 支持 MySQL 8.4、Percona 8.0、MariaDB 11.5 (带 ColumnStore)
- 自动错误检测和修复机制
- CentOS 7 优化构建
- 完整的依赖管理

**触发条件**:
- 推送到 main 分支且修改了工作流文件
- 手动触发 (workflow_dispatch)
- 每周一凌晨3点 UTC 自动构建

**输入参数**:
- `auto_fix_errors`: 启用自动错误修复 (默认: true)
- `force_latest_deps`: 强制更新到最新依赖版本 (默认: true)

### 2. `mysql-rocksdb-build.yml` - MySQL + RocksDB 构建
**用途**: 专注于 MySQL 和 RocksDB 的构建

**特性**:
- 同时构建 MySQL/Percona 和独立 RocksDB
- 自动错误修复功能
- MariaDB ColumnStore 支持

**触发条件**:
- 推送、PR、手动触发
- 每周日凌晨2点 UTC 自动构建

**输入参数**:
- `mysql_version`: MySQL 版本分支 (默认: "8.4")
- `rocksdb_version`: RocksDB 版本分支 (默认: "main")  
- `auto_fix_errors`: 启用自动错误修复 (默认: true)

### 3. `standalone-rocksdb.yml` - 独立 RocksDB 构建
**用途**: 专门构建 RocksDB 库

**特性**:
- 支持 CentOS 7 和 Ubuntu 20.04
- 全功能构建 (所有压缩算法)
- 包含工具和基准测试程序
- 静态库和动态库
- 构建测试验证

**触发条件**:
- 推送、PR、手动触发  
- 每周二凌晨4点 UTC 自动构建

**输入参数**:
- `rocksdb_version`: RocksDB 分支/标签 (默认: "main")
- `enable_all_features`: 启用所有 RocksDB 功能 (默认: true)

### 4. `percona80-rocksdb.yml` - 增强版 Percona 构建 (现有)
**用途**: 原有工作流的增强版本

**增强内容**:
- 添加了自动错误修复输入参数
- 保持向后兼容性

## 🔧 自动错误修复机制

### 支持的错误类型
1. **Jemalloc 链接错误**: 自动添加正确的链接标志和库路径
2. **头文件缺失**: 自动查找并添加包含路径
3. **库路径问题**: 自动配置 library 搜索路径
4. **Protobuf 版本冲突**: 强制使用 bundled 版本
5. **C++ 标准问题**: 自动设置 C++17 标准
6. **内存不足**: 减少并行编译进程数

### 重试机制
- 最多重试 3 次
- 每次重试都会应用相应的修复措施
- 失败时输出详细的错误日志

## 📦 依赖管理

### vcpkg 包列表
- `rocksdb`: RocksDB 数据库引擎
- `openssl`: SSL/TLS 加密库
- `zlib`: 通用压缩库
- `lz4`: 高速压缩算法
- `zstd`: Facebook 的压缩算法
- `snappy`: Google 的压缩算法
- `jemalloc`: 高性能内存分配器
- `bzip2`: 压缩算法
- `gflags`: 命令行标志库
- `boost`: C++ 库集合
- `curl`: HTTP 客户端库
- `protobuf`: 协议缓冲区

### 版本策略
- 自动使用 vcpkg 中的最新稳定版本
- 可通过 `force_latest_deps` 参数强制更新
- 定期自动构建确保版本新鲜度

## 🏗️ 构建环境

### CentOS 7 (主要平台)
- 使用最快的镜像源
- 现代 GCC 编译器 (来自 indiff/gcc-build)
- CMake 3.31.8
- 完整的开发工具链

### Ubuntu 20.04 (RocksDB)
- 系统包管理器 + vcpkg 混合
- 标准 GCC 编译器
- 完整的构建环境

## 📋 输出产物

### 包命名规则
- `mysql84-enhanced-centos7-YYYYMMDD_HHMM.xz`
- `percona80-enhanced-centos7-YYYYMMDD_HHMM.xz`
- `mariadb115-enhanced-centos7-YYYYMMDD_HHMM.xz`
- `rocksdb-standalone-centos7-YYYYMMDD_HHMM.xz`
- `rocksdb-standalone-ubuntu2004-YYYYMMDD_HHMM.xz`

### 包内容
- 完整的二进制文件和库
- 运行时依赖库
- 配置文件模板
- 版本信息文件
- 优化的 RPATH 设置

## 🚀 使用方式

### 手动触发构建
1. 进入 GitHub Actions 页面
2. 选择相应的工作流
3. 点击 "Run workflow"
4. 设置所需参数并运行

### 下载和安装
```bash
# 下载预编译包
cd /opt
curl -L "https://github.com/indiff/indiff/releases/download/[TAG]/[包名]" -o package.xz

# 或使用代理下载 (中国用户)
curl -L "https://ghproxy.cfd/https://github.com/indiff/indiff/releases/download/[TAG]/[包名]" -o package.xz

# 解压安装
unzip package.xz

# 设置环境变量 (根据需要)
export PATH="/opt/mysql/bin:$PATH"
export LD_LIBRARY_PATH="/opt/mysql/lib:$LD_LIBRARY_PATH"
```

### RocksDB 使用示例
```cpp
#include <rocksdb/db.h>

int main() {
    rocksdb::DB* db;
    rocksdb::Options options;
    options.create_if_missing = true;
    
    rocksdb::Status status = rocksdb::DB::Open(options, "/tmp/testdb", &db);
    // ... 使用数据库
    
    delete db;
    return 0;
}
```

编译时链接:
```bash
g++ -std=c++17 main.cpp -lrocksdb -o myapp
```

## 🔍 故障排除

### 常见问题
1. **编译内存不足**: 工作流会自动检测并减少并行度
2. **依赖库版本冲突**: 使用 bundled 版本或最新 vcpkg 版本
3. **链接错误**: 自动修复机制会处理大部分链接问题

### 查看构建日志
- GitHub Actions 页面查看实时构建日志
- 构建失败时会上传详细的错误日志文件

### 获取帮助
- 查看 GitHub Issues
- 检查 GitHub Actions 运行历史
- 参考现有的成功构建日志

## 📈 版本历史

### v1.0 (当前)
- 基础 MySQL/Percona/MariaDB 构建
- RocksDB 集成
- 自动错误修复机制
- vcpkg 依赖管理
- CentOS 7 优化

### 计划中功能
- Windows 平台支持
- ARM64 架构支持
- 更多存储引擎集成
- 性能优化配置选项
- 容器化部署支持

---

**维护者**: indiff  
**最后更新**: 2025-01-16  
**许可证**: 请参考各个组件的原始许可证