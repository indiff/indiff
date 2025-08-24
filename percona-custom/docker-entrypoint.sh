#!/bin/bash
set -eo pipefail

# Initialize database if necessary
if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing database..."
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql
fi

# Start MySQL in the background to configure it
mysqld --user=mysql --datadir=/var/lib/mysql --skip-networking &
mysql_pid=$!

# Wait for MySQL to start
until mysqladmin ping >/dev/null 2>&1; do
    sleep 1
done

# Set root password and create database/user
mysql -u root <<-EOSQL
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL

# Stop the background MySQL
kill $mysql_pid
wait $mysql_pid

# Start MySQL normally
exec mysqld --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 "$@"