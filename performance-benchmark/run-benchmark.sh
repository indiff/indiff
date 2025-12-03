#!/bin/bash
# Database Performance Benchmark Runner
# Author: indiff

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "Database Performance Benchmark"
echo "========================================"
echo ""

# Build the project if needed
if [ ! -f "target/db-performance-benchmark-1.0.0-jar-with-dependencies.jar" ]; then
    echo "Building project..."
    mvn clean package
    echo ""
fi

# Check if config file exists
CONFIG_FILE="${1:-benchmark.properties}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found: $CONFIG_FILE"
    echo ""
    echo "Creating example configuration..."
    
    if [ -f "benchmark.properties.example" ]; then
        cp benchmark.properties.example "$CONFIG_FILE"
        echo "Created $CONFIG_FILE from example"
        echo ""
        echo "Please edit $CONFIG_FILE with your database settings and run again."
        exit 1
    else
        echo "Example configuration not found!"
        echo "Running with default configuration (may not work)..."
        echo ""
        java -jar target/db-performance-benchmark-1.0.0-jar-with-dependencies.jar
        exit $?
    fi
fi

# Run the benchmark
echo "Running benchmark with configuration: $CONFIG_FILE"
echo ""
java -Xmx1g -jar target/db-performance-benchmark-1.0.0-jar-with-dependencies.jar "$CONFIG_FILE"

echo ""
echo "Benchmark completed!"
echo ""
echo "Generated reports:"
ls -lh benchmark-results-*.json benchmark-report-*.md 2>/dev/null | tail -2 || echo "No reports found"
echo ""
echo "Check benchmark.log for detailed logs"
