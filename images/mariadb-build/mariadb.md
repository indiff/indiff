[root@DDI_HOST:/opt/mariadb/lib/plugin]# /opt/mariadb/bin/mysql --socket=/opt/mariadb/data/mariadb.sock
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 9
Server version: 13.1.0-MariaDB-indiff-log MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Help others discover MariaDB. Star it on GitHub: https://github.com/MariaDB/server

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> use maria
Database changed
MariaDB [maria]> show engine;
ERROR 1064 (42000): You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near '' at line 1
MariaDB [maria]> show engines;
+--------------------+---------+-------------------------------------------------------------------------------------------------+--------------+------+------------+
| Engine             | Support | Comment                                                                                         | Transactions | XA   | Savepoints |
+--------------------+---------+-------------------------------------------------------------------------------------------------+--------------+------+------------+
| ROCKSDB            | YES     | RocksDB storage engine                                                                          | YES          | YES  | YES        |
| CSV                | YES     | Stores tables as CSV files                                                                      | NO           | NO   | NO         |
| MRG_MyISAM         | YES     | Collection of identical MyISAM tables                                                           | NO           | NO   | NO         |
| Aria               | YES     | Crash-safe tables with MyISAM heritage. Used for internal temporary tables and privilege tables | NO           | NO   | NO         |
| MyISAM             | YES     | Non-transactional engine with good performance and small data footprint                         | NO           | NO   | NO         |
| MEMORY             | YES     | Hash based, stored in memory, useful for temporary tables                                       | NO           | NO   | NO         |
| InnoDB             | DEFAULT | Supports transactions, row-level locking, foreign keys and encryption for tables                | YES          | YES  | YES        |
| SEQUENCE           | YES     | Generated tables filled with sequential values                                                  | YES          | NO   | YES        |
| PERFORMANCE_SCHEMA | YES     | Performance Schema                                                                              | NO           | NO   | NO         |
+--------------------+---------+-------------------------------------------------------------------------------------------------+--------------+------+------------+
9 rows in set (0.001 sec)

MariaDB [maria]> CREATE TABLE user_events (
         id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
         user_id    BIGINT UNSIGNED NOT NULL,
         event_type VARCHAR(50)     NOT NULL,
         created_at DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
         payload    JSON,
         PRIMARY KEY (id),
         INDEX idx_user_time (user_id, created_at)
     ) ENGINE=RocksDB
       COMMENT='用户行为事件表，高写入+时间范围查询';
Query OK, 0 rows affected (0.016 sec)

MariaDB [maria]> INSERT INTO user_events (user_id, event_type, payload)
     VALUES
       (1001, 'login',   '{"ip":"10.0.0.1"}'),
       (1001, 'purchase', '{"item":"SKU-889","amount":299.00}'),
       (1002, 'login',   '{"ip":"10.0.0.5"}');
Query OK, 3 rows affected (0.008 sec)
Records: 3  Duplicates: 0  Warnings: 0

MariaDB [maria]> SELECT * FROM user_events
     WHERE user_id = 1001
       AND created_at >= '2026-09-01'
     ORDER BY created_at DESC
     LIMIT 100;
Empty set (0.004 sec)

MariaDB [maria]> INSTALL SONAME 'ha_duckdb';
Query OK, 0 rows affected (0.164 sec)

MariaDB [maria]> show engines;
+--------------------+---------+-------------------------------------------------------------------------------------------------+--------------+------+------------+
| Engine             | Support | Comment                                                                                         | Transactions | XA   | Savepoints |
+--------------------+---------+-------------------------------------------------------------------------------------------------+--------------+------+------------+
| ROCKSDB            | YES     | RocksDB storage engine                                                                          | YES          | YES  | YES        |
| CSV                | YES     | Stores tables as CSV files                                                                      | NO           | NO   | NO         |
| MRG_MyISAM         | YES     | Collection of identical MyISAM tables                                                           | NO           | NO   | NO         |
| Aria               | YES     | Crash-safe tables with MyISAM heritage. Used for internal temporary tables and privilege tables | NO           | NO   | NO         |
| MyISAM             | YES     | Non-transactional engine with good performance and small data footprint                         | NO           | NO   | NO         |
| MEMORY             | YES     | Hash based, stored in memory, useful for temporary tables                                       | NO           | NO   | NO         |
| InnoDB             | DEFAULT | Supports transactions, row-level locking, foreign keys and encryption for tables                | YES          | YES  | YES        |
| SEQUENCE           | YES     | Generated tables filled with sequential values                                                  | YES          | NO   | YES        |
| DUCKDB             | YES     | DuckDB storage engine                                                                           | YES          | YES  | NO         |
| PERFORMANCE_SCHEMA | YES     | Performance Schema                                                                              | NO           | NO   | NO         |
+--------------------+---------+-------------------------------------------------------------------------------------------------+--------------+------+------------+
10 rows in set (0.003 sec)

MariaDB [maria]> CREATE TABLE sales_analytics (
         sale_date   DATE,
         region      VARCHAR(50),
         product     VARCHAR(100),
         quantity    INT,
         revenue     DECIMAL(15,2)
     ) ENGINE=DuckDB;
ERROR 1173 (42000): This table type requires a primary key
MariaDB [maria]> CREATE TABLE sales_analytics (
     idVARCHAR(10),
         sale_date   DATE,
         region      VARCHAR(50),
         product     VARCHAR(100),
         quantity    INT,
         revenue     DECIMAL(15,2),
     primary key (id)
     ) ENGINE=DuckDB;
ERROR 1064 (42000): You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near '(10),
    sale_date   DATE,
    region      VARCHAR(50),
    product     VARC...' at line 2
MariaDB [maria]> CREATE TABLE sales_analytics (
         id    INT,
         sale_date   DATE,
         region      VARCHAR(50),
         product     VARCHAR(100),
         quantity    INT,
         revenue     DECIMAL(15,2),
     primary key (id)
     ) ENGINE=DuckDB;
Query OK, 0 rows affected (0.017 sec)

MariaDB [maria]> INSERT INTO sales_analytics VALUES
       (1,'2026-09-01', 'East',  'Widget-A', 150, 4500.00),
       (2,'2026-09-01', 'West',  'Widget-B', 230, 6900.00),
       (3,'2026-09-02', 'East',  'Widget-A', 180, 5400.00),
       (4,'2026-09-02', 'East',  'Widget-A', 180, 5400.00),
       (5,'2026-09-02', 'East',  'Widget-A', 180, 5400.00),
       (6,'2026-09-02', 'East',  'Widget-A', 180, 5400.00),
       (7,'2026-09-02', 'East',  'Widget-A', 180, 5400.00),
       (8,'2026-09-02', 'East',  'Widget-A', 180, 5400.00),
       (9,'2026-09-02', 'East',  'Widget-A', 180, 5400.00),
       (10,'2026-09-02', 'East',  'Widget-A', 180, 5400.00),
       (11,'2026-09-02', 'North', 'Widget-C', 90,  3600.00);
Query OK, 11 rows affected (0.023 sec)
Records: 11  Duplicates: 0  Warnings: 0

MariaDB [maria]> SELECT
         region,
         SUM(revenue)   AS total_revenue,
         AVG(quantity)  AS avg_qty,
         COUNT(*)       AS txns
     FROM sales_analytics
     WHERE sale_date BETWEEN '2026-09-01' AND '2026-09-30'
     GROUP BY region
     ORDER BY total_revenue DESC;
+--------+---------------+----------+------+
| region | total_revenue | avg_qty  | txns |
+--------+---------------+----------+------+
| East   |      47700.00 | 176.6667 |    9 |
| West   |       6900.00 | 230.0000 |    1 |
| North  |       3600.00 |  90.0000 |    1 |
+--------+---------------+----------+------+
3 rows in set (0.022 sec)

MariaDB [maria]> 
