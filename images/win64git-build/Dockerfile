# change my base
ARG GH_REPO=ghcr.io/indiff/ffmpeg-builds
FROM $GH_REPO/base:latest

RUN --mount=src=ct-ng-config,dst=/.config \
    git clone --filter=blob:none https://github.com/crosstool-ng/crosstool-ng.git /ct-ng && cd /ct-ng && \
    ./bootstrap && \
    ./configure --enable-local && \
    make -j$(nproc) && \
    cp /.config .config && \
    ./ct-ng build && \
    cd / && \
    rm -rf ct-ng

# Prepare "cross" environment to heavily favour static builds
RUN \
    find /opt/ct-ng \
        -name "*.dll" \
        -or -name "*.dll.a" \
        -delete && \
    mkdir /opt/git

ENV GIT_TOOLCHAIN=x86_64-w64-mingw32 \
    GIT_RUST_TARGET=x86_64-pc-windows-gnu

RUN \
    rustup target add "$GIT_RUST_TARGET" && \
    echo "[target.$GIT_RUST_TARGET]\nlinker = \"${GIT_TOOLCHAIN}-gcc\"\nar = \"${GIT_TOOLCHAIN}-gcc-ar\"\n" > "$CARGO_HOME"/config.toml

ADD toolchain.cmake /toolchain.cmake
ADD cross.meson /cross.meson

LABEL maintainer="indiff"
LABEL description="CentOS 7 build environment for git compilation"

ENV PATH="/opt/ct-ng/bin:${PATH}" \
    GIT_TARGET_FLAGS="--pkg-config=pkg-config --cross-prefix=${GIT_TOOLCHAIN}- --arch=x86_64 --target-os=mingw32" \
    GIT_CROSS_PREFIX=${GIT_TOOLCHAIN}- \
    GIT_PREFIX=/opt/git \
    GIT_DESTDIR=/opt/ffdest \
    GIT_DESTPREFIX=/opt/ffdest/opt/git \
    GIT_CMAKE_TOOLCHAIN=/toolchain.cmake \
    PKG_CONFIG=pkg-config \
    PKG_CONFIG_LIBDIR=/opt/git/lib/pkgconfig:/opt/git/share/pkgconfig \
    CC="${GIT_TOOLCHAIN}-gcc" \
    CXX="${GIT_TOOLCHAIN}-g++" \
    LD="${GIT_TOOLCHAIN}-ld" \
    AR="${GIT_TOOLCHAIN}-gcc-ar" \
    RANLIB="${GIT_TOOLCHAIN}-gcc-ranlib" \
    NM="${GIT_TOOLCHAIN}-gcc-nm" \
    DLLTOOL="${GIT_TOOLCHAIN}-dlltool" \
    GENDEF="${GIT_TOOLCHAIN}-gendef" \
    CFLAGS="-static-libgcc -static-libstdc++ -I/opt/git/include -O3 -pipe -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    CXXFLAGS="-static-libgcc -static-libstdc++ -I/opt/git/include -O3 -pipe -D_FORTIFY_SOURCE=2 -fstack-protector-strong" \
    LDFLAGS="-static-libgcc -static-libstdc++ -L/opt/git/lib -O3 -pipe -fstack-protector-strong" \
    STAGE_CFLAGS="-fno-semantic-interposition" \
    STAGE_CXXFLAGS="-fno-semantic-interposition"
	
# Copy dependency installation script
COPY dependency.sh /tmp/dependency.sh

# Run the installation script
RUN chmod +x /tmp/dependency.sh && \
    /tmp/dependency.sh && \
    rm -f /tmp/dependency.sh

# Set working directory
WORKDIR /workspace


SHELL ["/bin/bash", "-c"]
CMD ["/bin/bash"]
