FROM ghcr.io/cirruslabs/flutter:stable@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8

ARG FLUTTER_VERSION=3.47.2
ARG GIT_VERSION=2.50.0
ARG GIT_SHA256=dff3c000e400ace3a63b8a6f8b3b76b88ecfdffd4504a04aba4248372cdec045

ENV DEBIAN_FRONTEND=noninteractive \
    BOORUSAMA_USE_FVM=false \
    PUB_CACHE=/root/.pub-cache \
    CARGO_HOME=/root/.cargo \
    RUSTUP_HOME=/opt/rustup \
    PATH=/opt/rust-cargo/bin:${PATH}

RUN git -C /sdks/flutter fetch --depth=1 origin "refs/tags/${FLUTTER_VERSION}" \
    && git -C /sdks/flutter checkout --detach FETCH_HEAD \
    && flutter precache --android \
    && flutter --version \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        curl \
        gettext \
        libcurl4-openssl-dev \
        libexpat1-dev \
        libssl-dev \
        meson \
        nasm \
        ninja-build \
        pkg-config \
        xz-utils \
        zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSLo /tmp/git.tar.xz "https://www.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.xz" \
    && echo "${GIT_SHA256}  /tmp/git.tar.xz" | sha256sum --check --strict \
    && mkdir /tmp/git-source \
    && tar -xJf /tmp/git.tar.xz --strip-components=1 -C /tmp/git-source \
    && make -C /tmp/git-source -j"$(nproc)" prefix=/usr/local NO_TCLTK=YesPlease all \
    && make -C /tmp/git-source prefix=/usr/local NO_TCLTK=YesPlease install \
    && /usr/local/bin/git --version | grep -F -- "git version ${GIT_VERSION}" \
    && rm -rf /tmp/git-source /tmp/git.tar.xz

RUN curl --proto '=https' --tlsv1.2 -fsSLo /tmp/rustup-init https://sh.rustup.rs \
    && chmod +x /tmp/rustup-init \
    && CARGO_HOME=/opt/rust-cargo /tmp/rustup-init -y --profile minimal --default-toolchain 1.92.0 \
    && CARGO_HOME=/opt/rust-cargo /opt/rust-cargo/bin/rustup target add \
        aarch64-linux-android \
        armv7-linux-androideabi \
        i686-linux-android \
        x86_64-linux-android \
    && rm /tmp/rustup-init

RUN sdkmanager \
      "build-tools;35.0.0" \
      "cmake;3.22.1" \
      "ndk;27.0.12077973" \
      "ndk;28.2.13676358" \
      "platforms;android-34" \
      "platforms;android-35"

# The base image caches its own release label. Regenerate it after checking out
# the pinned Flutter tag so diagnostics report the actual SDK version.
RUN git -C /sdks/flutter fetch origin "refs/tags/${FLUTTER_VERSION}:refs/tags/${FLUTTER_VERSION}" \
    && rm -f /sdks/flutter/bin/cache/flutter.version.json \
    && flutter --version

RUN apt-get update \
    && apt-get install -y --no-install-recommends socat \
    && rm -rf /var/lib/apt/lists/*

COPY .devcontainer/adb-wrapper.sh /tmp/adb-wrapper.sh
RUN mv /opt/android-sdk-linux/platform-tools/adb /opt/android-sdk-linux/platform-tools/adb.real \
    && mv /tmp/adb-wrapper.sh /opt/android-sdk-linux/platform-tools/adb \
    && chmod +x /opt/android-sdk-linux/platform-tools/adb

WORKDIR /workspace/Boorusama
