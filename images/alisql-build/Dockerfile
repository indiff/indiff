FROM oraclelinux:7
LABEL maintainer="indiff"
LABEL description="Oracle Linux 7 build environment for AliSQL (aligned with official CI: devtoolset-10 + CMake 3.28.6 + build.sh)"

# gcc-indiff toolchain (RHEL7-compatible, works on both CentOS7 and OracleLinux7)
ARG gcc_indiff_centos7_url
ENV gcc_indiff_centos7_url=${gcc_indiff_centos7_url}

# AliSQL build args (can be overridden at build time)
# ARG ALISQL_BRANCH
# ARG ALISQL_INSTALL_PREFIX
# ARG VCPKG_ROOT

# Copy dependency installation script
COPY oraclelinux7.sh /tmp/oraclelinux7.sh

# Run the installation script
RUN chmod +x /tmp/oraclelinux7.sh && \
    /tmp/oraclelinux7.sh && \
    rm -f /tmp/oraclelinux7.sh

# Set working directory
WORKDIR /workspace
ENV PATH=/opt/gcc-indiff/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/gcc-indiff/lib:/opt/gcc-indiff/lib64:$LD_LIBRARY_PATH
ENV CC=/opt/gcc-indiff/bin/gcc
ENV CXX=/opt/gcc-indiff/bin/g++
SHELL ["/bin/bash", "-c"]
CMD ["/bin/bash"]
