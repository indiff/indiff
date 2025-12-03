package com.indiff.benchmark;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;

/**
 * Main class for running database performance benchmarks
 */
public class PerformanceBenchmark {
    private static final Logger logger = LoggerFactory.getLogger(PerformanceBenchmark.class);
    
    public static void main(String[] args) {
        logger.info("Starting Database Performance Benchmark");
        
        List<DatabaseConfig> configs = new ArrayList<>();
        
        // Check if a properties file is provided
        if (args.length > 0) {
            try {
                configs = loadConfigsFromFile(args[0]);
            } catch (IOException e) {
                logger.error("Failed to load configuration file: {}", args[0], e);
                System.err.println("Error loading configuration: " + e.getMessage());
                System.exit(1);
            }
        } else {
            // Use default configurations for demonstration
            configs = getDefaultConfigs();
        }
        
        if (configs.isEmpty()) {
            logger.error("No database configurations found");
            System.err.println("No database configurations found. Please provide a configuration file.");
            printUsage();
            System.exit(1);
        }
        
        // Run benchmarks
        List<BenchmarkResult> results = new ArrayList<>();
        
        for (DatabaseConfig config : configs) {
            logger.info("Running benchmarks for: {}", config.getName());
            BenchmarkExecutor executor = null;
            try {
                executor = new BenchmarkExecutor(config);
                BenchmarkResult result = executor.runBenchmarks();
                results.add(result);
            } catch (Exception e) {
                logger.error("Failed to run benchmarks for: {}", config.getName(), e);
                System.err.println("Error running benchmarks for " + config.getName() + ": " + e.getMessage());
            } finally {
                if (executor != null) {
                    executor.close();
                }
            }
        }
        
        // Generate reports
        if (!results.isEmpty()) {
            ReportGenerator.generateConsoleReport(results);
            
            try {
                String timestamp = String.valueOf(System.currentTimeMillis());
                ReportGenerator.generateJsonReport(results, "benchmark-results-" + timestamp + ".json");
                ReportGenerator.generateMarkdownReport(results, "benchmark-report-" + timestamp + ".md");
            } catch (IOException e) {
                logger.error("Failed to generate report files", e);
                System.err.println("Error generating report files: " + e.getMessage());
            }
        } else {
            logger.warn("No benchmark results to report");
            System.err.println("No benchmark results were generated.");
        }
        
        logger.info("Database Performance Benchmark completed");
    }
    
    private static List<DatabaseConfig> loadConfigsFromFile(String filename) throws IOException {
        List<DatabaseConfig> configs = new ArrayList<>();
        Properties props = new Properties();
        
        try (FileInputStream fis = new FileInputStream(filename)) {
            props.load(fis);
        }
        
        // Parse database configurations
        // Format: db.N.name, db.N.type, db.N.url, db.N.username, db.N.password
        int index = 1;
        while (true) {
            String prefix = "db." + index + ".";
            String name = props.getProperty(prefix + "name");
            
            if (name == null) {
                break; // No more databases
            }
            
            String type = props.getProperty(prefix + "type");
            String url = props.getProperty(prefix + "url");
            String username = props.getProperty(prefix + "username", "");
            String password = props.getProperty(prefix + "password", "");
            
            if (type != null && url != null) {
                configs.add(new DatabaseConfig(name, type, url, username, password));
                logger.info("Loaded configuration: {}", name);
            }
            
            index++;
        }
        
        return configs;
    }
    
    private static List<DatabaseConfig> getDefaultConfigs() {
        List<DatabaseConfig> configs = new ArrayList<>();
        
        // Example configurations - users should modify these
        logger.warn("Using default configurations. These may not work in your environment.");
        logger.warn("Please provide a configuration file with your database settings.");
        
        // Example MySQL configuration
        configs.add(new DatabaseConfig(
            "Custom MySQL (indiff build)",
            "mysql",
            "jdbc:mysql://localhost:3306/benchmark?useSSL=false&allowPublicKeyRetrieval=true",
            "root",
            "password"
        ));
        
        // Example PostgreSQL configuration
        configs.add(new DatabaseConfig(
            "Custom PostgreSQL (indiff build)",
            "postgresql",
            "jdbc:postgresql://localhost:5432/benchmark",
            "postgres",
            "password"
        ));
        
        // Example MariaDB configuration
        configs.add(new DatabaseConfig(
            "Custom MariaDB (indiff build)",
            "mariadb",
            "jdbc:mariadb://localhost:3306/benchmark",
            "root",
            "password"
        ));
        
        return configs;
    }
    
    private static void printUsage() {
        System.out.println("\nUsage: java -jar db-performance-benchmark.jar [config-file]");
        System.out.println("\nConfiguration file format:");
        System.out.println("db.1.name=Custom MySQL");
        System.out.println("db.1.type=mysql");
        System.out.println("db.1.url=jdbc:mysql://localhost:3306/benchmark");
        System.out.println("db.1.username=root");
        System.out.println("db.1.password=password");
        System.out.println("\ndb.2.name=Custom PostgreSQL");
        System.out.println("db.2.type=postgresql");
        System.out.println("db.2.url=jdbc:postgresql://localhost:5432/benchmark");
        System.out.println("db.2.username=postgres");
        System.out.println("db.2.password=password");
        System.out.println("\nSupported database types: mysql, postgresql, mariadb\n");
    }
}
