# 预编译 MySQL 安装包详细分析报告

## 概述

本报告分析了 GitHub Release `20250823_2217_mysql` 中发布的三个 MySQL 预编译安装包，虽然文件后缀为 `.xz`，但实际上都是 ZIP 格式的压缩包。

## 分析的包

1. **MariaDB CentOS7 版本**: `maria-centos7-x86_64-20250823_2037.xz` (229MB)
2. **Percona Server 8.0 CentOS7 版本**: `percona80-centos7-x86_64-20250823_2214.xz` (275MB)  
3. **Percona Server 8.0 Ubuntu 版本**: `percona80-ubuntu-x86_64-20250823_1143.xz` (328MB)

## 文件格式问题

**重要发现**: 所有三个文件虽然以 `.xz` 为后缀，但实际文件格式为 **ZIP 压缩包**，而非 XZ 压缩格式。
```bash
$ file *.xz
maria-centos7.xz:     Zip archive data, at least v2.0 to extract
percona80-centos7.xz: Zip archive data, at least v2.0 to extract  
percona80-ubuntu.xz:  Zip archive data, at least v2.0 to extract
```

## 详细版本信息

### 1. MariaDB CentOS7 版本

**数据库版本**: MariaDB (基于构建文件推测为 11.x 版本)

**核心依赖库版本**:
- **OpenSSL**: 3.0.x (vcpkg 安装)
- **zlib**: 1.3.1 (vcpkg 安装，高于系统默认的 1.2.x)
- **zstd**: 1.5.7 (vcpkg 安装)
- **libcurl**: 8.15.0-DEV (vcpkg 安装，开发版本)
- **snappy**: 1.2.2 (vcpkg 安装)

**存储引擎支持**:
- ✅ **RocksDB**: 完整支持 (ha_rocksdb.so - 11.5MB)
- ✅ **Mroonga**: 全文搜索引擎 (ha_mroonga.so - 7MB)
- ✅ **Spider**: 分片引擎 (ha_spider.so - 1.3MB)
- ✅ **Connect**: 外部数据源连接 (ha_connect.so - 3.6MB)
- ✅ **S3**: 对象存储引擎 (ha_s3.so)

### 2. Percona Server 8.0 CentOS7 版本

**数据库版本**: 由于缺少运行时依赖，无法直接获取版本，但根据文件名和构建配置推测为 8.0.42-33

**核心依赖库版本**:
- **GCC 运行时**: libstdc++.so.6.0.34 (来自 GCC 16.0.0)
- **jemalloc**: 系统版本 (CentOS 7 自带)
- **zstd**: 1.5.8 (vcpkg 安装)
- **原子操作库**: libatomic.so.1.2.0 (GCC 16.0.0)

**存储引擎支持**:
- ✅ **RocksDB**: 完整支持 (ha_rocksdb.so - 14.9MB，比 MariaDB 版本更大)

### 3. Percona Server 8.0 Ubuntu 版本

**数据库版本**: 8.0.42-33 for Linux on x86_64 (Source distribution)

**核心特性**:
- **jemalloc 支持**: 包含 jemalloc 头文件
- **客户端库**: libperconaserverclient.so.21.2.42 (14.9MB)

**存储引擎支持**:
- ✅ **RocksDB**: 完整支持 (ha_rocksdb.so - 14.5MB)

## vcpkg vs 系统依赖对比

### vcpkg 安装的库 (版本较新)

| 库名称 | vcpkg 版本 | 典型系统版本 | 优势 |
|--------|------------|--------------|------|
| **OpenSSL** | 3.0.x | 1.1.1 (CentOS7) | 更好的安全性和性能 |
| **zlib** | 1.3.1 | 1.2.11 | 更好的压缩效率 |
| **zstd** | 1.5.7/1.5.8 | 1.4.x | 更快的压缩速度 |
| **libcurl** | 8.15.0-DEV | 7.x | 更多功能和安全修复 |
| **snappy** | 1.2.2 | 1.1.x | 更好的压缩性能 |

### 系统依赖的库

| 库名称 | 包中版本 | 说明 |
|--------|----------|------|
| **jemalloc** | 系统版本 | CentOS 7 自带版本，用于内存管理优化 |
| **libaio** | 系统版本 | 异步 I/O，数据库性能关键 |
| **libnuma** | 系统版本 | NUMA 架构优化 |

### 构建工具链版本

**GCC 版本**: 使用了来自 `indiff/gcc-build` 项目的 **GCC 16.0.0** 构建
- 位置: `https://github.com/indiff/gcc-build/releases/download/20250818_1113_16.0.0/`
- 这比大多数系统默认的 GCC 版本（通常 4.8-9.x）**显著更新**

## 依赖库来源分析

### 完全由 vcpkg 提供
- ✅ OpenSSL (加密库)
- ✅ zlib (通用压缩)  
- ✅ zstd (高速压缩)
- ✅ snappy (快速压缩，RocksDB 依赖)
- ✅ libcurl (HTTP 客户端)
- ✅ LZ4 (超快压缩)

### 混合来源 (vcpkg + 系统)
- ⚡ **protobuf**: 使用 bundled 版本（构建时内置）
- ⚡ **boost**: 使用下载的版本，非系统版本

### 完全使用系统版本
- 🏛️ **jemalloc**: 系统包管理器安装
- 🏛️ **libaio**: 系统库  
- 🏛️ **libnuma**: 系统库
- 🏛️ **readline/libedit**: 系统库

## 性能测试建议

### 1. 压缩性能测试
由于包含了多个新版本的压缩库，可以测试：

```bash
# RocksDB 压缩性能测试
# 测试 snappy, lz4, zstd 三种压缩算法的性能

# 在 MySQL 中设置不同的压缩
SET GLOBAL rocksdb_default_cf_options = 'compression=snappy';
SET GLOBAL rocksdb_default_cf_options = 'compression=lz4';  
SET GLOBAL rocksdb_default_cf_options = 'compression=zstd';
```

### 2. 内存管理性能测试
测试 jemalloc 的内存管理效果：

```bash
# 监控内存分配效率
jemalloc_stats() {
  echo 'SELECT @@jemalloc_profiling;' | mysql
}

# 高并发插入测试
sysbench --mysql-host=127.0.0.1 oltp_insert --tables=10 --table-size=1000000 run
```

### 3. I/O 性能基准测试

```bash
# 使用 sysbench 测试不同存储引擎性能
sysbench fileio --file-test-mode=rndrw --file-total-size=20G prepare
sysbench fileio --file-test-mode=rndrw --file-total-size=20G run

# RocksDB vs InnoDB 性能对比
# InnoDB 表
CREATE TABLE test_innodb (id INT PRIMARY KEY, data TEXT) ENGINE=InnoDB;

# RocksDB 表  
CREATE TABLE test_rocksdb (id INT PRIMARY KEY, data TEXT) ENGINE=RocksDB;
```

### 4. 网络性能测试 (libcurl 8.15.0)
测试 HTTP 相关功能的性能提升：

```sql
-- 测试 HTTP 函数性能 (如果支持)
SELECT HTTP_GET('http://example.com/api/data');
```

## 兼容性考虑

### 向前兼容性 ✅
- 使用了 RPATH 设置，运行时库路径为相对路径
- 大部分依赖库版本向前兼容

### 潜在问题 ⚠️
- **glibc 依赖**: CentOS 7 构建的版本可能需要特定的 glibc 版本
- **动态库加载**: 某些系统可能缺少运行时依赖 (如 readline, libedit)

## 总结

这三个预编译包展现了以下特点：

1. **技术先进性**: 大量使用 vcpkg 管理的新版本依赖库，版本普遍高于系统默认版本
2. **性能优化**: 集成了 RocksDB 存储引擎和多种高效压缩算法
3. **构建质量**: 使用 GCC 16.0.0 这样的新版本编译器，可能具有更好的优化效果
4. **功能完整**: MariaDB 版本包含了丰富的存储引擎支持

**推荐使用场景**:
- 需要高性能压缩的大数据场景
- 需要 RocksDB 存储引擎的写密集型应用  
- 对安全性要求高的环境 (新版 OpenSSL)
- 需要最新功能特性的开发测试环境

**注意事项**:
- 部署前需要安装必要的运行时依赖
- 建议在测试环境充分验证兼容性后再用于生产
- 文件命名不规范 (.xz 后缀但为 ZIP 格式) 需要注意