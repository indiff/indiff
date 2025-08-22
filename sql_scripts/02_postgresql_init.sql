-- PostgreSQL 数据库初始化脚本
-- Database Initialization Script for PostgreSQL

-- 创建性能测试数据库 (如果不是在初始化时创建)
-- CREATE DATABASE benchmark_test WITH ENCODING 'UTF8' LC_COLLATE='zh_CN.UTF-8' LC_CTYPE='zh_CN.UTF-8';

-- 连接到测试数据库
\c benchmark_test;

-- 创建测试用户 (如果需要)
-- CREATE USER benchmark WITH PASSWORD 'password';
-- GRANT ALL PRIVILEGES ON DATABASE benchmark_test TO benchmark;

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- 创建性能测试表结构
CREATE TABLE IF NOT EXISTS performance_test (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    username VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status SMALLINT DEFAULT 1,
    score DECIMAL(10,2) DEFAULT 0.00,
    data_json JSONB,
    uuid UUID DEFAULT uuid_generate_v4(),
    search_vector TSVECTOR
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_performance_test_user_id ON performance_test(user_id);
CREATE INDEX IF NOT EXISTS idx_performance_test_username ON performance_test(username);
CREATE INDEX IF NOT EXISTS idx_performance_test_email ON performance_test(email);
CREATE INDEX IF NOT EXISTS idx_performance_test_created_at ON performance_test(created_at);
CREATE INDEX IF NOT EXISTS idx_performance_test_status ON performance_test(status);
CREATE INDEX IF NOT EXISTS idx_performance_test_score ON performance_test(score);

-- JSON 字段索引
CREATE INDEX IF NOT EXISTS idx_performance_test_json_level ON performance_test USING GIN ((data_json->'level'));
CREATE INDEX IF NOT EXISTS idx_performance_test_json_badges ON performance_test USING GIN ((data_json->'badges'));

-- 全文搜索索引
CREATE INDEX IF NOT EXISTS idx_performance_test_search ON performance_test USING GIN(search_vector);

-- 创建基准测试日志表
CREATE TABLE IF NOT EXISTS benchmark_log (
    id BIGSERIAL PRIMARY KEY,
    test_name VARCHAR(100) NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    end_time TIMESTAMP WITH TIME ZONE,
    threads INTEGER NOT NULL,
    qps DECIMAL(12,2),
    tps DECIMAL(12,2),
    avg_latency DECIMAL(8,3),
    p95_latency DECIMAL(8,3),
    p99_latency DECIMAL(8,3),
    errors INTEGER DEFAULT 0,
    notes TEXT
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_benchmark_log_test_name ON benchmark_log(test_name);
CREATE INDEX IF NOT EXISTS idx_benchmark_log_start_time ON benchmark_log(start_time);

-- 创建触发器函数用于更新 updated_at 字段
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建触发器
DROP TRIGGER IF EXISTS update_performance_test_updated_at ON performance_test;
CREATE TRIGGER update_performance_test_updated_at
    BEFORE UPDATE ON performance_test
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 创建触发器函数用于更新搜索向量
CREATE OR REPLACE FUNCTION update_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := 
        setweight(to_tsvector('english', coalesce(NEW.username, '')), 'A') ||
        setweight(to_tsvector('english', coalesce(NEW.email, '')), 'B');
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 创建搜索向量触发器
DROP TRIGGER IF EXISTS update_performance_test_search_vector ON performance_test;
CREATE TRIGGER update_performance_test_search_vector
    BEFORE INSERT OR UPDATE ON performance_test
    FOR EACH ROW
    EXECUTE FUNCTION update_search_vector();

-- 插入初始测试数据
INSERT INTO performance_test (user_id, username, email, score, data_json) VALUES
(1, 'user1', 'user1@example.com', 85.50, '{"level": 1, "badges": ["newcomer"], "last_login": "2024-01-15", "preferences": {"theme": "dark", "notifications": true}}'),
(2, 'user2', 'user2@example.com', 92.30, '{"level": 2, "badges": ["achiever", "expert"], "last_login": "2024-01-16", "preferences": {"theme": "light", "notifications": false}}'),
(3, 'user3', 'user3@example.com', 78.90, '{"level": 1, "badges": ["newcomer", "learner"], "last_login": "2024-01-14", "preferences": {"theme": "auto", "notifications": true}}'),
(4, 'user4', 'user4@example.com', 95.20, '{"level": 3, "badges": ["master", "expert", "leader"], "last_login": "2024-01-17", "preferences": {"theme": "dark", "notifications": true}}'),
(5, 'user5', 'user5@example.com', 88.70, '{"level": 2, "badges": ["achiever"], "last_login": "2024-01-13", "preferences": {"theme": "light", "notifications": false}}');

-- 创建存储过程用于生成测试数据
CREATE OR REPLACE FUNCTION generate_test_data(num_records INTEGER)
RETURNS void AS $$
DECLARE
    i INTEGER := 1;
    random_level INTEGER;
    random_badge TEXT;
    random_theme TEXT;
    random_notifications BOOLEAN;
BEGIN
    WHILE i <= num_records LOOP
        random_level := floor(random() * 5) + 1;
        
        random_badge := CASE floor(random() * 4)
            WHEN 0 THEN 'newcomer'
            WHEN 1 THEN 'achiever'
            WHEN 2 THEN 'expert'
            ELSE 'master'
        END;
        
        random_theme := CASE floor(random() * 3)
            WHEN 0 THEN 'dark'
            WHEN 1 THEN 'light'
            ELSE 'auto'
        END;
        
        random_notifications := random() > 0.3;
        
        INSERT INTO performance_test (
            user_id, 
            username, 
            email, 
            score, 
            data_json
        ) VALUES (
            i,
            'user' || i,
            'user' || i || '@example.com',
            round((random() * 100)::numeric, 2),
            jsonb_build_object(
                'level', random_level,
                'badges', jsonb_build_array(random_badge),
                'last_login', (NOW() - interval '1 day' * floor(random() * 30))::date,
                'preferences', jsonb_build_object(
                    'theme', random_theme,
                    'notifications', random_notifications
                )
            )
        );
        
        i := i + 1;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 创建性能分析函数
CREATE OR REPLACE FUNCTION analyze_performance()
RETURNS TABLE(
    metric_name TEXT,
    metric_value NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'total_records'::TEXT, 
        COUNT(*)::NUMERIC 
    FROM performance_test
    
    UNION ALL
    
    SELECT 
        'avg_score'::TEXT, 
        AVG(score)::NUMERIC 
    FROM performance_test
    
    UNION ALL
    
    SELECT 
        'max_score'::TEXT, 
        MAX(score)::NUMERIC 
    FROM performance_test
    
    UNION ALL
    
    SELECT 
        'min_score'::TEXT, 
        MIN(score)::NUMERIC 
    FROM performance_test;
END;
$$ LANGUAGE plpgsql;

-- 创建性能测试视图
CREATE OR REPLACE VIEW performance_summary AS
SELECT 
    DATE(created_at) as test_date,
    COUNT(*) as total_records,
    AVG(score) as avg_score,
    MIN(score) as min_score,
    MAX(score) as max_score,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) FILTER (WHERE data_json->>'level' = '1') as level_1_users,
    COUNT(*) FILTER (WHERE data_json->>'level' = '2') as level_2_users,
    COUNT(*) FILTER (WHERE data_json->>'level' = '3') as level_3_users
FROM performance_test 
GROUP BY DATE(created_at)
ORDER BY test_date;

-- 创建 JSON 数据分析视图
CREATE OR REPLACE VIEW json_analysis AS
SELECT 
    data_json->>'level' as user_level,
    COUNT(*) as user_count,
    AVG(score) as avg_score,
    jsonb_agg(DISTINCT jsonb_array_elements_text(data_json->'badges')) as all_badges
FROM performance_test 
GROUP BY data_json->>'level'
ORDER BY user_level;

-- 显示表信息
\dt

-- 显示当前数据统计
SELECT 'PostgreSQL Database Initialized Successfully' as status;
SELECT COUNT(*) as initial_records FROM performance_test;

-- 性能分析
SELECT * FROM analyze_performance();

-- 显示使用提示
SELECT '使用以下命令生成更多测试数据:' as tip
UNION ALL
SELECT 'SELECT generate_test_data(10000);' as example;

-- 显示可用的视图
\dv