-- 创建测试数据库和表
CREATE DATABASE IF NOT EXISTS test_replication;
USE test_replication;

-- 基本测试表 (InnoDB)
CREATE TABLE IF NOT EXISTS basic_test (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150),
    age INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 插入测试数据
INSERT INTO basic_test (name, email, age) VALUES
('张三', 'zhangsan@example.com', 25),
('李四', 'lisi@example.com', 30),
('王五', 'wangwu@example.com', 28),
('赵六', 'zhaoliu@example.com', 35),
('钱七', 'qianqi@example.com', 22);

-- 大数据量测试表
CREATE TABLE IF NOT EXISTS performance_test (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    data1 VARCHAR(255),
    data2 TEXT,
    data3 DECIMAL(10,2),
    data4 DATE,
    data5 JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 批量插入性能测试数据
DELIMITER $$
CREATE PROCEDURE InsertTestData(IN num_rows INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= num_rows DO
        INSERT INTO performance_test (data1, data2, data3, data4, data5) VALUES
        (
            CONCAT('test_data_', i),
            REPEAT('Lorem ipsum dolor sit amet, consectetur adipiscing elit. ', 10),
            ROUND(RAND() * 1000, 2),
            DATE_ADD('2023-01-01', INTERVAL FLOOR(RAND() * 365) DAY),
            JSON_OBJECT('id', i, 'random', RAND(), 'timestamp', NOW())
        );
        SET i = i + 1;
        IF i % 100 = 0 THEN
            COMMIT;
        END IF;
    END WHILE;
END$$
DELIMITER ;

-- 创建索引测试表
CREATE TABLE IF NOT EXISTS index_test (
    id INT PRIMARY KEY AUTO_INCREMENT,
    category VARCHAR(50),
    subcategory VARCHAR(50),
    value DECIMAL(10,4),
    status ENUM('active', 'inactive', 'pending'),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_category (category),
    INDEX idx_subcategory (subcategory),
    INDEX idx_status (status),
    INDEX idx_created (created_at)
) ENGINE=InnoDB;

-- 事务测试表
CREATE TABLE IF NOT EXISTS transaction_test (
    id INT PRIMARY KEY AUTO_INCREMENT,
    account_id INT NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    transaction_type ENUM('debit', 'credit') NOT NULL,
    balance DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_account (account_id)
) ENGINE=InnoDB;

-- 创建存储过程用于并发测试
DELIMITER $$
CREATE PROCEDURE ConcurrentInsertTest(IN thread_id INT, IN num_inserts INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    
    WHILE i <= num_inserts DO
        START TRANSACTION;
        INSERT INTO transaction_test (account_id, amount, transaction_type, balance) VALUES
        (thread_id, ROUND(RAND() * 1000, 2), 
         IF(RAND() > 0.5, 'credit', 'debit'), 
         ROUND(RAND() * 10000, 2));
        COMMIT;
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;