package com.indiff.benchmark;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.*;
import java.util.ArrayList;
import java.util.List;

/**
 * Database benchmark executor
 */
public class BenchmarkExecutor {
    private static final Logger logger = LoggerFactory.getLogger(BenchmarkExecutor.class);
    
    private DatabaseConfig config;
    private HikariDataSource dataSource;
    
    public BenchmarkExecutor(DatabaseConfig config) {
        this.config = config;
        initializeDataSource();
    }
    
    private void initializeDataSource() {
        HikariConfig hikariConfig = new HikariConfig();
        hikariConfig.setJdbcUrl(config.getUrl());
        hikariConfig.setUsername(config.getUsername());
        hikariConfig.setPassword(config.getPassword());
        hikariConfig.setDriverClassName(config.getDriver());
        hikariConfig.setMaximumPoolSize(10);
        hikariConfig.setMinimumIdle(2);
        hikariConfig.setConnectionTimeout(30000);
        hikariConfig.setIdleTimeout(600000);
        hikariConfig.setMaxLifetime(1800000);
        
        this.dataSource = new HikariDataSource(hikariConfig);
    }
    
    public BenchmarkResult runBenchmarks() {
        BenchmarkResult result = new BenchmarkResult(config.getName(), config.getType());
        
        logger.info("Starting benchmarks for: {}", config.getName());
        
        // Run various benchmark tests
        result.addTestResult("connection", testConnectionPerformance());
        result.addTestResult("simple_select", testSimpleSelect());
        result.addTestResult("create_table", testCreateTable());
        result.addTestResult("insert_single", testSingleInsert());
        result.addTestResult("insert_batch", testBatchInsert());
        result.addTestResult("select_range", testSelectRange());
        result.addTestResult("update", testUpdate());
        result.addTestResult("delete", testDelete());
        
        logger.info("Completed benchmarks for: {}", config.getName());
        
        return result;
    }
    
    private BenchmarkResult.TestResult testConnectionPerformance() {
        BenchmarkResult.TestResult testResult = new BenchmarkResult.TestResult("Connection Performance");
        int iterations = 100;
        List<Long> times = new ArrayList<>();
        
        try {
            for (int i = 0; i < iterations; i++) {
                long start = System.nanoTime();
                try (Connection conn = dataSource.getConnection()) {
                    // Just get connection
                }
                long end = System.nanoTime();
                times.add((end - start) / 1_000_000); // Convert to ms
            }
            
            calculateAndSetTiming(testResult, times, iterations);
        } catch (Exception e) {
            logger.error("Connection test failed", e);
            testResult.setError(e.getMessage());
        }
        
        return testResult;
    }
    
    private BenchmarkResult.TestResult testSimpleSelect() {
        BenchmarkResult.TestResult testResult = new BenchmarkResult.TestResult("Simple Select");
        int iterations = 1000;
        List<Long> times = new ArrayList<>();
        
        try (Connection conn = dataSource.getConnection()) {
            // Create test table
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_test");
                stmt.execute("CREATE TABLE bench_test (id INT PRIMARY KEY, value VARCHAR(100))");
                stmt.execute("INSERT INTO bench_test VALUES (1, 'test')");
            }
            
            // Run benchmark
            for (int i = 0; i < iterations; i++) {
                long start = System.nanoTime();
                try (Statement stmt = conn.createStatement();
                     ResultSet rs = stmt.executeQuery("SELECT * FROM bench_test WHERE id = 1")) {
                    if (rs.next()) {
                        rs.getString("value");
                    }
                }
                long end = System.nanoTime();
                times.add((end - start) / 1_000_000);
            }
            
            calculateAndSetTiming(testResult, times, iterations);
            
            // Cleanup
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_test");
            }
        } catch (Exception e) {
            logger.error("Simple select test failed", e);
            testResult.setError(e.getMessage());
        }
        
        return testResult;
    }
    
    private BenchmarkResult.TestResult testCreateTable() {
        BenchmarkResult.TestResult testResult = new BenchmarkResult.TestResult("Create Table");
        int iterations = 10;
        List<Long> times = new ArrayList<>();
        
        try (Connection conn = dataSource.getConnection()) {
            for (int i = 0; i < iterations; i++) {
                String tableName = "bench_create_" + i;
                long start = System.nanoTime();
                try (Statement stmt = conn.createStatement()) {
                    stmt.execute("CREATE TABLE " + tableName + " (id INT PRIMARY KEY, name VARCHAR(100), created_at TIMESTAMP)");
                }
                long end = System.nanoTime();
                times.add((end - start) / 1_000_000);
                
                // Cleanup
                try (Statement stmt = conn.createStatement()) {
                    stmt.execute("DROP TABLE IF EXISTS " + tableName);
                }
            }
            
            calculateAndSetTiming(testResult, times, iterations);
        } catch (Exception e) {
            logger.error("Create table test failed", e);
            testResult.setError(e.getMessage());
        }
        
        return testResult;
    }
    
    private BenchmarkResult.TestResult testSingleInsert() {
        BenchmarkResult.TestResult testResult = new BenchmarkResult.TestResult("Single Insert");
        int iterations = 1000;
        List<Long> times = new ArrayList<>();
        
        try (Connection conn = dataSource.getConnection()) {
            // Create test table
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_insert");
                stmt.execute("CREATE TABLE bench_insert (id INT PRIMARY KEY, value VARCHAR(100))");
            }
            
            // Run benchmark
            for (int i = 0; i < iterations; i++) {
                long start = System.nanoTime();
                try (PreparedStatement pstmt = conn.prepareStatement("INSERT INTO bench_insert VALUES (?, ?)")) {
                    pstmt.setInt(1, i);
                    pstmt.setString(2, "value_" + i);
                    pstmt.executeUpdate();
                }
                long end = System.nanoTime();
                times.add((end - start) / 1_000_000);
            }
            
            calculateAndSetTiming(testResult, times, iterations);
            
            // Cleanup
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_insert");
            }
        } catch (Exception e) {
            logger.error("Single insert test failed", e);
            testResult.setError(e.getMessage());
        }
        
        return testResult;
    }
    
    private BenchmarkResult.TestResult testBatchInsert() {
        BenchmarkResult.TestResult testResult = new BenchmarkResult.TestResult("Batch Insert");
        int batchSize = 100;
        int batches = 10;
        List<Long> times = new ArrayList<>();
        
        try (Connection conn = dataSource.getConnection()) {
            // Create test table
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_batch");
                stmt.execute("CREATE TABLE bench_batch (id INT PRIMARY KEY, value VARCHAR(100))");
            }
            
            // Run benchmark
            for (int b = 0; b < batches; b++) {
                long start = System.nanoTime();
                try (PreparedStatement pstmt = conn.prepareStatement("INSERT INTO bench_batch VALUES (?, ?)")) {
                    for (int i = 0; i < batchSize; i++) {
                        int id = b * batchSize + i;
                        pstmt.setInt(1, id);
                        pstmt.setString(2, "value_" + id);
                        pstmt.addBatch();
                    }
                    pstmt.executeBatch();
                }
                long end = System.nanoTime();
                times.add((end - start) / 1_000_000);
            }
            
            calculateAndSetTiming(testResult, times, batches);
            
            // Cleanup
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_batch");
            }
        } catch (Exception e) {
            logger.error("Batch insert test failed", e);
            testResult.setError(e.getMessage());
        }
        
        return testResult;
    }
    
    private BenchmarkResult.TestResult testSelectRange() {
        BenchmarkResult.TestResult testResult = new BenchmarkResult.TestResult("Select Range");
        int iterations = 100;
        List<Long> times = new ArrayList<>();
        
        try (Connection conn = dataSource.getConnection()) {
            // Create and populate test table
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_select");
                stmt.execute("CREATE TABLE bench_select (id INT PRIMARY KEY, value VARCHAR(100))");
                
                try (PreparedStatement pstmt = conn.prepareStatement("INSERT INTO bench_select VALUES (?, ?)")) {
                    for (int i = 0; i < 1000; i++) {
                        pstmt.setInt(1, i);
                        pstmt.setString(2, "value_" + i);
                        pstmt.addBatch();
                    }
                    pstmt.executeBatch();
                }
            }
            
            // Run benchmark
            for (int i = 0; i < iterations; i++) {
                long start = System.nanoTime();
                try (PreparedStatement pstmt = conn.prepareStatement("SELECT * FROM bench_select WHERE id >= ? AND id < ?")) {
                    pstmt.setInt(1, i * 10);
                    pstmt.setInt(2, (i + 1) * 10);
                    try (ResultSet rs = pstmt.executeQuery()) {
                        while (rs.next()) {
                            rs.getInt("id");
                            rs.getString("value");
                        }
                    }
                }
                long end = System.nanoTime();
                times.add((end - start) / 1_000_000);
            }
            
            calculateAndSetTiming(testResult, times, iterations);
            
            // Cleanup
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_select");
            }
        } catch (Exception e) {
            logger.error("Select range test failed", e);
            testResult.setError(e.getMessage());
        }
        
        return testResult;
    }
    
    private BenchmarkResult.TestResult testUpdate() {
        BenchmarkResult.TestResult testResult = new BenchmarkResult.TestResult("Update");
        int iterations = 100;
        List<Long> times = new ArrayList<>();
        
        try (Connection conn = dataSource.getConnection()) {
            // Create and populate test table
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_update");
                stmt.execute("CREATE TABLE bench_update (id INT PRIMARY KEY, value VARCHAR(100))");
                
                try (PreparedStatement pstmt = conn.prepareStatement("INSERT INTO bench_update VALUES (?, ?)")) {
                    for (int i = 0; i < iterations; i++) {
                        pstmt.setInt(1, i);
                        pstmt.setString(2, "value_" + i);
                        pstmt.addBatch();
                    }
                    pstmt.executeBatch();
                }
            }
            
            // Run benchmark
            for (int i = 0; i < iterations; i++) {
                long start = System.nanoTime();
                try (PreparedStatement pstmt = conn.prepareStatement("UPDATE bench_update SET value = ? WHERE id = ?")) {
                    pstmt.setString(1, "updated_" + i);
                    pstmt.setInt(2, i);
                    pstmt.executeUpdate();
                }
                long end = System.nanoTime();
                times.add((end - start) / 1_000_000);
            }
            
            calculateAndSetTiming(testResult, times, iterations);
            
            // Cleanup
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_update");
            }
        } catch (Exception e) {
            logger.error("Update test failed", e);
            testResult.setError(e.getMessage());
        }
        
        return testResult;
    }
    
    private BenchmarkResult.TestResult testDelete() {
        BenchmarkResult.TestResult testResult = new BenchmarkResult.TestResult("Delete");
        int iterations = 100;
        List<Long> times = new ArrayList<>();
        
        try (Connection conn = dataSource.getConnection()) {
            for (int batch = 0; batch < 10; batch++) {
                // Create and populate test table
                try (Statement stmt = conn.createStatement()) {
                    stmt.execute("DROP TABLE IF EXISTS bench_delete");
                    stmt.execute("CREATE TABLE bench_delete (id INT PRIMARY KEY, value VARCHAR(100))");
                    
                    try (PreparedStatement pstmt = conn.prepareStatement("INSERT INTO bench_delete VALUES (?, ?)")) {
                        for (int i = 0; i < 10; i++) {
                            pstmt.setInt(1, i);
                            pstmt.setString(2, "value_" + i);
                            pstmt.addBatch();
                        }
                        pstmt.executeBatch();
                    }
                }
                
                // Run benchmark
                for (int i = 0; i < 10; i++) {
                    long start = System.nanoTime();
                    try (PreparedStatement pstmt = conn.prepareStatement("DELETE FROM bench_delete WHERE id = ?")) {
                        pstmt.setInt(1, i);
                        pstmt.executeUpdate();
                    }
                    long end = System.nanoTime();
                    times.add((end - start) / 1_000_000);
                }
            }
            
            calculateAndSetTiming(testResult, times, 100);
            
            // Cleanup
            try (Statement stmt = conn.createStatement()) {
                stmt.execute("DROP TABLE IF EXISTS bench_delete");
            }
        } catch (Exception e) {
            logger.error("Delete test failed", e);
            testResult.setError(e.getMessage());
        }
        
        return testResult;
    }
    
    private void calculateAndSetTiming(BenchmarkResult.TestResult testResult, List<Long> times, int iterations) {
        long total = times.stream().mapToLong(Long::longValue).sum();
        long avg = total / times.size();
        long min = times.stream().mapToLong(Long::longValue).min().orElse(0);
        long max = times.stream().mapToLong(Long::longValue).max().orElse(0);
        
        testResult.setTiming(total, avg, min, max, iterations);
    }
    
    public void close() {
        if (dataSource != null && !dataSource.isClosed()) {
            dataSource.close();
        }
    }
}
