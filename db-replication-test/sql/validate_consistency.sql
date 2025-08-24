-- 数据一致性验证查询

-- 检查表记录数一致性
SELECT 
    'basic_test' as table_name,
    COUNT(*) as record_count,
    MAX(created_at) as last_update,
    CHECKSUM TABLE basic_test as table_checksum
FROM basic_test

UNION ALL

SELECT 
    'performance_test' as table_name,
    COUNT(*) as record_count,
    MAX(created_at) as last_update,
    NULL as table_checksum
FROM performance_test

UNION ALL

SELECT 
    'index_test' as table_name,
    COUNT(*) as record_count,
    MAX(created_at) as last_update,
    NULL as table_checksum
FROM index_test

UNION ALL

SELECT 
    'transaction_test' as table_name,
    COUNT(*) as record_count,
    MAX(created_at) as last_update,
    NULL as table_checksum
FROM transaction_test;

-- 检查数据完整性
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT id) as unique_ids,
    MIN(id) as min_id,
    MAX(id) as max_id,
    AVG(age) as avg_age
FROM basic_test;

-- 检查最新插入的数据
SELECT * FROM basic_test ORDER BY created_at DESC LIMIT 10;

-- 检查索引使用情况
SHOW INDEX FROM basic_test;
SHOW INDEX FROM performance_test;
SHOW INDEX FROM index_test;
SHOW INDEX FROM transaction_test;