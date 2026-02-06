# Oracle Metadata Export Tool

通过 Oracle 数据库（兼容 11.2.0.4+）获取存储过程、触发器、包、函数、视图等元数据，以 `.sql` 文件形式保存到本地 Git 仓库。首次运行自动初始化仓库并提交；后续每次运行自动检测变更并提交，借助 Git 的 diff 能力追踪元数据变化。

## Features / 功能

- 连接 Oracle 数据库，通过 `DBMS_METADATA.GET_DDL` 提取对象 DDL
- 支持导出：`PROCEDURE`、`FUNCTION`、`TRIGGER`、`PACKAGE`、`PACKAGE_BODY`、`VIEW`、`TYPE`、`TYPE_BODY`、`SYNONYM`、`SEQUENCE`、`TABLE`
- 按 `<schema>/<object_type>/<object_name>.sql` 目录结构保存
- 首次运行自动 `git init` + 初始提交
- 后续运行自动检测文件新增/修改/删除并提交
- 通过 Git 历史记录追踪所有变更

## Requirements / 依赖

- Python 3.7+
- `oracledb` (Python 驱动，纯 Python 模式兼容 Oracle 11.2.0.4)
- Git

```bash
pip install -r requirements.txt
```

## Configuration / 配置

复制 `config.ini.example` 为 `config.ini`，根据实际环境修改：

```bash
cp config.ini.example config.ini
```

配置项说明：

| Section    | Key           | Description                                      |
|------------|---------------|--------------------------------------------------|
| database   | host          | Oracle 数据库地址                                 |
| database   | port          | 端口（默认 1521）                                  |
| database   | service_name  | 服务名                                            |
| database   | user          | 用户名                                            |
| database   | password      | 密码                                              |
| export     | output_dir    | 导出文件存放目录（即 Git 仓库目录）                  |
| export     | object_types  | 要导出的对象类型（逗号分隔）                        |
| export     | schemas       | 要导出的 Schema（留空使用当前用户）                  |
| export     | encoding      | 文件编码（默认 utf-8）                              |
| git        | auto_commit   | 是否自动提交（true/false）                          |
| git        | commit_prefix | 提交信息前缀                                       |

## Usage / 使用

```bash
# 使用默认 config.ini
python oracle_meta_export.py

# 指定配置文件
python oracle_meta_export.py -c /path/to/config.ini

# 启用调试日志
python oracle_meta_export.py -v
```

## Output Structure / 输出结构

```
oracle_metadata_repo/
├── .git/
├── SCOTT/
│   ├── procedures/
│   │   ├── MY_PROC.sql
│   │   └── ANOTHER_PROC.sql
│   ├── functions/
│   │   └── MY_FUNC.sql
│   ├── triggers/
│   │   └── MY_TRIGGER.sql
│   ├── packages/
│   │   └── MY_PKG.sql
│   ├── package_bodies/
│   │   └── MY_PKG.sql
│   └── views/
│       └── MY_VIEW.sql
└── HR/
    └── procedures/
        └── ...
```

## How It Works / 工作原理

1. 读取配置文件中的数据库连接信息和导出选项
2. 检查输出目录是否已有 Git 仓库，没有则 `git init`
3. 连接 Oracle 数据库，查询 `ALL_OBJECTS` 获取对象列表
4. 使用 `DBMS_METADATA.GET_DDL` 获取每个对象的 DDL
5. 将 DDL 写入对应目录的 `.sql` 文件
6. 检测文件变更（新增、修改、删除），自动 `git add -A && git commit`
7. 通过 `git log` / `git diff` 可查看历史变更

## Testing / 测试

```bash
cd oracle-metadata
python -m pytest tests/ -v
```

所有 Oracle 交互均使用 mock，无需实际数据库连接即可运行测试。
