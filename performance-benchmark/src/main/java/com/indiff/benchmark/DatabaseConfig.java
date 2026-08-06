package com.indiff.benchmark;

import java.sql.Connection;
import java.sql.SQLException;

/**
 * Database configuration holder
 */
public class DatabaseConfig {
    private String name;
    private String driver;
    private String url;
    private String username;
    private String password;
    private String type; // mysql, postgresql, mariadb

    public DatabaseConfig(String name, String type, String url, String username, String password) {
        this.name = name;
        this.type = type;
        this.url = url;
        this.username = username;
        this.password = password;
        
        // Set driver based on type
        switch (type.toLowerCase()) {
            case "mysql":
                this.driver = "com.mysql.cj.jdbc.Driver";
                break;
            case "postgresql":
            case "postgres":
            case "pg":
                this.driver = "org.postgresql.Driver";
                break;
            case "mariadb":
                this.driver = "org.mariadb.jdbc.Driver";
                break;
            default:
                throw new IllegalArgumentException("Unsupported database type: " + type);
        }
    }

    public String getName() {
        return name;
    }

    public String getDriver() {
        return driver;
    }

    public String getUrl() {
        return url;
    }

    public String getUsername() {
        return username;
    }

    public String getPassword() {
        return password;
    }

    public String getType() {
        return type;
    }

    @Override
    public String toString() {
        return "DatabaseConfig{" +
                "name='" + name + '\'' +
                ", type='" + type + '\'' +
                ", url='" + url + '\'' +
                '}';
    }
}
