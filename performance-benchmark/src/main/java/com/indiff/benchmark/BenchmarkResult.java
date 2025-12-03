package com.indiff.benchmark;

import java.util.*;

/**
 * Benchmark result holder
 */
public class BenchmarkResult {
    private String databaseName;
    private String databaseType;
    private Map<String, TestResult> testResults;
    
    public BenchmarkResult(String databaseName, String databaseType) {
        this.databaseName = databaseName;
        this.databaseType = databaseType;
        this.testResults = new LinkedHashMap<>();
    }
    
    public void addTestResult(String testName, TestResult result) {
        testResults.put(testName, result);
    }
    
    public String getDatabaseName() {
        return databaseName;
    }
    
    public String getDatabaseType() {
        return databaseType;
    }
    
    public Map<String, TestResult> getTestResults() {
        return testResults;
    }
    
    public static class TestResult {
        private String testName;
        private long totalTimeMs;
        private long avgTimeMs;
        private long minTimeMs;
        private long maxTimeMs;
        private int iterations;
        private boolean success;
        private String errorMessage;
        private long throughput; // operations per second
        
        public TestResult(String testName) {
            this.testName = testName;
            this.success = true;
        }
        
        public void setTiming(long totalTimeMs, long avgTimeMs, long minTimeMs, long maxTimeMs, int iterations) {
            this.totalTimeMs = totalTimeMs;
            this.avgTimeMs = avgTimeMs;
            this.minTimeMs = minTimeMs;
            this.maxTimeMs = maxTimeMs;
            this.iterations = iterations;
            
            if (totalTimeMs > 0) {
                this.throughput = (iterations * 1000L) / totalTimeMs;
            }
        }
        
        public void setError(String errorMessage) {
            this.success = false;
            this.errorMessage = errorMessage;
        }

        public String getTestName() {
            return testName;
        }

        public long getTotalTimeMs() {
            return totalTimeMs;
        }

        public long getAvgTimeMs() {
            return avgTimeMs;
        }

        public long getMinTimeMs() {
            return minTimeMs;
        }

        public long getMaxTimeMs() {
            return maxTimeMs;
        }

        public int getIterations() {
            return iterations;
        }

        public boolean isSuccess() {
            return success;
        }

        public String getErrorMessage() {
            return errorMessage;
        }

        public long getThroughput() {
            return throughput;
        }
    }
}
