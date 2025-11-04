FROM centos:7

LABEL maintainer="indiff"
LABEL description="CentOS 7 build environment for mysql compilation"

ARG PG_VERSION_TAG
ARG TIMESCALEDB_VERSION
ARG POSTGIS_VERSION_TAG
ARG INSTALL_PREFIX
ARG VCPKG_TRIPLET
ARG gcc_indiff_centos7_url

ENV PG_VERSION_TAG=${PG_VERSION_TAG} \
    TIMESCALEDB_VERSION=${TIMESCALEDB_VERSION} \
    POSTGIS_VERSION_TAG=${POSTGIS_VERSION_TAG} \
    INSTALL_PREFIX=${INSTALL_PREFIX} \
    VCPKG_TRIPLET=${VCPKG_TRIPLET} \
    gcc_indiff_centos7_url=${gcc_indiff_centos7_url}
    
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
