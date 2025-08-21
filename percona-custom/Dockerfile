FROM centos:7

# Install basic dependencies
RUN yum install -y wget tar xz libaio numactl-libs && \
    yum clean all

# Download and extract pre-compiled Percona with RocksDB
RUN cd /opt && \
    wget -O percona80-centos7.xz https://github.com/indiff/indiff/releases/download/20250821_0401_percona80/percona80-centos7-x86_64-20250821_0358.xz && \
    xz -d percona80-centos7.xz && \
    tar -xf percona80-centos7 && \
    rm percona80-centos7 && \
    mv mysql-percona80 /usr/local/mysql

# Create mysql user and data directory
RUN useradd -M -r -s /bin/false mysql && \
    mkdir -p /var/lib/mysql /var/log/mysql /var/run/mysqld && \
    chown -R mysql:mysql /var/lib/mysql /var/log/mysql /var/run/mysqld

# Set environment variables
ENV PATH="/usr/local/mysql/bin:$PATH"
ENV LD_LIBRARY_PATH="/usr/local/mysql/lib:$LD_LIBRARY_PATH"

# Create necessary directories and permissions
RUN mkdir -p /etc/mysql/conf.d && \
    mkdir -p /docker-entrypoint-initdb.d

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3306

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["mysqld"]