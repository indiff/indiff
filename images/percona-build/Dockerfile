FROM centos:7

LABEL maintainer="indiff"
LABEL description="CentOS 7 build environment for mysql compilation"

# ARG MYSQL_BRANCH
# ARG VCPKG_ROOT
# ARG INSTALL_PREFIX
# ARG PERCONA_BRANCH
# ARG PERCONA_INSTALL_PREFIX
# ARG gcc_indiff_centos7_url
ARG gcc_indiff_centos7_url
ENV gcc_indiff_centos7_url=${gcc_indiff_centos7_url}
# ENV MYSQL_BRANCH=${MYSQL_BRANCH} \
#     VCPKG_ROOT=${VCPKG_ROOT} \
#     INSTALL_PREFIX=${INSTALL_PREFIX} \
#     PERCONA_BRANCH=${PERCONA_BRANCH} \
#     PERCONA_INSTALL_PREFIX=${PERCONA_INSTALL_PREFIX} \
#     gcc_indiff_centos7_url=${gcc_indiff_centos7_url}
    
# Copy dependency installation script
COPY centos7.sh /tmp/centos7.sh

# Run the installation script
RUN chmod +x /tmp/centos7.sh && \
    /tmp/centos7.sh && \
    rm -f /tmp/centos7.sh

# Set working directory
WORKDIR /workspace

ENV PATH=/opt/gcc-indiff/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/gcc-indiff/lib:/opt/gcc-indiff/lib64:$LD_LIBRARY_PATH
ENV CC=/opt/gcc-indiff/bin/gcc
ENV CXX=/opt/gcc-indiff/bin/g++

SHELL ["/bin/bash", "-c"]
CMD ["/bin/bash"]
