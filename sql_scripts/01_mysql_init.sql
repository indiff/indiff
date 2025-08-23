-- MySQL 数据库初始化脚本
-- Database Initialization Script for MySQL

-- 创建性能测试数据库
CREATE DATABASE IF NOT EXISTS benchmark_test 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE benchmark_test;

-- 创建测试用户
CREATE USER IF NOT EXISTS 'benchmark'@'%' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON benchmark_test.* TO 'benchmark'@'%';
FLUSH PRIVILEGES;

-- 创建性能测试表结构
CREATE TABLE IF NOT EXISTS performance_test (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    username VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    status TINYINT DEFAULT 1,
    score DECIMAL(10,2) DEFAULT 0.00,
    data_json JSON,
    INDEX idx_user_id (user_id),
    INDEX idx_username (username),
    INDEX idx_email (email),
    INDEX idx_created_at (created_at),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 创建日志表
CREATE TABLE IF NOT EXISTS benchmark_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    test_name VARCHAR(100) NOT NULL,
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP NULL,
    threads INT NOT NULL,
    qps DECIMAL(12,2),
    tps DECIMAL(12,2),
    avg_latency DECIMAL(8,3),
    p95_latency DECIMAL(8,3),
    p99_latency DECIMAL(8,3),
    errors INT DEFAULT 0,
    notes TEXT,
    INDEX idx_test_name (test_name),
    INDEX idx_start_time (start_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 插入一些初始测试数据
INSERT INTO performance_test (user_id, username, email, score, data_json) VALUES
(1, 'user1', 'user1@example.com', 85.50, '{"level": 1, "badges": ["newcomer"]}'),
(2, 'user2', 'user2@example.com', 92.30, '{"level": 2, "badges": ["achiever", "expert"]}'),
(3, 'user3', 'user3@example.com', 78.90, '{"level": 1, "badges": ["newcomer", "learner"]}'),
(4, 'user4', 'user4@example.com', 95.20, '{"level": 3, "badges": ["master", "expert", "leader"]}'),
(5, 'user5', 'user5@example.com', 88.70, '{"level": 2, "badges": ["achiever"]}');

-- 创建存储过程用于生成测试数据
DELIMITER $$

CREATE PROCEDURE IF NOT EXISTS generate_test_data(IN num_records INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    
    WHILE i <= num_records DO
        INSERT INTO performance_test (
            user_id, 
            username, 
            email, 
            score, 
            data_json
        ) VALUES (
            i,
            CONCAT('user', i),
            CONCAT('user', i, '@example.com'),
            ROUND(RAND() * 100, 2),
            JSON_OBJECT(
                'level', FLOOR(RAND() * 5) + 1,
                'badges', JSON_ARRAY(
                    CASE FLOOR(RAND() * 4)
                        WHEN 0 THEN 'newcomer'
                        WHEN 1 THEN 'achiever'
                        WHEN 2 THEN 'expert'
                        ELSE 'master'
                    END
                ),
                'last_login', NOW(),
                'preferences', JSON_OBJECT(
                    'theme', IF(RAND() > 0.5, 'dark', 'light'),
                    'notifications', RAND() > 0.3
                )
            )
        );
        
        SET i = i + 1;
    END WHILE;
END$$

DELIMITER ;

-- 创建性能测试视图
CREATE OR REPLACE VIEW performance_summary AS
SELECT 
    DATE(created_at) as test_date,
    COUNT(*) as total_records,
    AVG(score) as avg_score,
    MIN(score) as min_score,
    MAX(score) as max_score,
    COUNT(DISTINCT user_id) as unique_users
FROM performance_test 
GROUP BY DATE(created_at);

-- 显示表信息
SHOW TABLES;
DESCRIBE performance_test;
DESCRIBE benchmark_log;

-- 显示当前数据统计
SELECT 'MySQL Database Initialized Successfully' as status;
SELECT COUNT(*) as initial_records FROM performance_test;

-- 提示如何使用
SELECT '使用以下命令生成更多测试数据:' as tip;
SELECT 'CALL generate_test_data(10000);' as example;