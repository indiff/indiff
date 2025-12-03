package com.indiff.benchmark;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;

import java.io.FileWriter;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Report generator for benchmark results
 */
public class ReportGenerator {
    
    public static void generateConsoleReport(List<BenchmarkResult> results) {
        System.out.println("\n" + "=".repeat(100));
        System.out.println("Database Performance Benchmark Report");
        System.out.println("=".repeat(100));
        
        for (BenchmarkResult result : results) {
            System.out.println("\n" + "-".repeat(100));
            System.out.println(String.format("Database: %s (%s)", result.getDatabaseName(), result.getDatabaseType()));
            System.out.println("-".repeat(100));
            
            System.out.println(String.format("%-25s %10s %10s %10s %10s %15s %10s", 
                "Test Name", "Avg (ms)", "Min (ms)", "Max (ms)", "Total (ms)", "Throughput/s", "Status"));
            System.out.println("-".repeat(100));
            
            for (Map.Entry<String, BenchmarkResult.TestResult> entry : result.getTestResults().entrySet()) {
                BenchmarkResult.TestResult testResult = entry.getValue();
                
                if (testResult.isSuccess()) {
                    System.out.println(String.format("%-25s %10d %10d %10d %10d %15d %10s",
                        testResult.getTestName(),
                        testResult.getAvgTimeMs(),
                        testResult.getMinTimeMs(),
                        testResult.getMaxTimeMs(),
                        testResult.getTotalTimeMs(),
                        testResult.getThroughput(),
                        "SUCCESS"
                    ));
                } else {
                    System.out.println(String.format("%-25s %10s %10s %10s %10s %15s %10s",
                        testResult.getTestName(),
                        "N/A", "N/A", "N/A", "N/A", "N/A",
                        "FAILED: " + testResult.getErrorMessage()
                    ));
                }
            }
        }
        
        System.out.println("\n" + "=".repeat(100));
        generateComparisonTable(results);
        System.out.println("=".repeat(100) + "\n");
    }
    
    private static void generateComparisonTable(List<BenchmarkResult> results) {
        if (results.size() < 2) {
            return;
        }
        
        System.out.println("\nPerformance Comparison (Average Time in ms - Lower is Better)");
        System.out.println("-".repeat(100));
        
        // Get all test names from first result
        BenchmarkResult firstResult = results.get(0);
        List<String> testNames = new ArrayList<>(firstResult.getTestResults().keySet());
        
        // Print header
        System.out.print(String.format("%-25s", "Test Name"));
        for (BenchmarkResult result : results) {
            System.out.print(String.format(" %20s", result.getDatabaseName()));
        }
        System.out.println();
        System.out.println("-".repeat(100));
        
        // Print each test
        for (String testName : testNames) {
            System.out.print(String.format("%-25s", testName));
            
            for (BenchmarkResult result : results) {
                BenchmarkResult.TestResult testResult = result.getTestResults().get(testName);
                if (testResult != null && testResult.isSuccess()) {
                    System.out.print(String.format(" %20d", testResult.getAvgTimeMs()));
                } else {
                    System.out.print(String.format(" %20s", "FAILED"));
                }
            }
            System.out.println();
        }
    }
    
    public static void generateJsonReport(List<BenchmarkResult> results, String filename) throws IOException {
        Gson gson = new GsonBuilder().setPrettyPrinting().create();
        
        try (FileWriter writer = new FileWriter(filename)) {
            gson.toJson(results, writer);
        }
        
        System.out.println("\nJSON report generated: " + filename);
    }
    
    public static void generateMarkdownReport(List<BenchmarkResult> results, String filename) throws IOException {
        StringBuilder md = new StringBuilder();
        
        md.append("# Database Performance Benchmark Report\n\n");
        md.append("## Summary\n\n");
        md.append("This report compares the performance of custom-built databases against standard configurations.\n\n");
        
        for (BenchmarkResult result : results) {
            md.append("## ").append(result.getDatabaseName()).append(" (").append(result.getDatabaseType()).append(")\n\n");
            
            md.append("| Test Name | Avg (ms) | Min (ms) | Max (ms) | Total (ms) | Throughput/s | Status |\n");
            md.append("|-----------|----------|----------|----------|------------|--------------|--------|\n");
            
            for (Map.Entry<String, BenchmarkResult.TestResult> entry : result.getTestResults().entrySet()) {
                BenchmarkResult.TestResult testResult = entry.getValue();
                
                if (testResult.isSuccess()) {
                    md.append(String.format("| %s | %d | %d | %d | %d | %d | ✓ |\n",
                        testResult.getTestName(),
                        testResult.getAvgTimeMs(),
                        testResult.getMinTimeMs(),
                        testResult.getMaxTimeMs(),
                        testResult.getTotalTimeMs(),
                        testResult.getThroughput()
                    ));
                } else {
                    md.append(String.format("| %s | N/A | N/A | N/A | N/A | N/A | ✗ (%s) |\n",
                        testResult.getTestName(),
                        testResult.getErrorMessage()
                    ));
                }
            }
            md.append("\n");
        }
        
        // Comparison table
        if (results.size() >= 2) {
            md.append("## Performance Comparison\n\n");
            md.append("Average execution time in milliseconds (lower is better):\n\n");
            
            // Get all test names
            List<String> testNames = new ArrayList<>(results.get(0).getTestResults().keySet());
            
            // Header
            md.append("| Test Name |");
            for (BenchmarkResult result : results) {
                md.append(" ").append(result.getDatabaseName()).append(" |");
            }
            md.append("\n|-----------|");
            for (int i = 0; i < results.size(); i++) {
                md.append("-----------|");
            }
            md.append("\n");
            
            // Data rows
            for (String testName : testNames) {
                md.append("| ").append(testName).append(" |");
                
                for (BenchmarkResult result : results) {
                    BenchmarkResult.TestResult testResult = result.getTestResults().get(testName);
                    if (testResult != null && testResult.isSuccess()) {
                        md.append(" ").append(testResult.getAvgTimeMs()).append(" |");
                    } else {
                        md.append(" FAILED |");
                    }
                }
                md.append("\n");
            }
            md.append("\n");
        }
        
        try (FileWriter writer = new FileWriter(filename)) {
            writer.write(md.toString());
        }
        
        System.out.println("Markdown report generated: " + filename);
    }
}
