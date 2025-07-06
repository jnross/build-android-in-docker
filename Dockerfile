FROM --platform=linux/amd64 ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git-core \
    gnupg \
    flex \
    bison \
    build-essential \
    zip \
    curl \
    zlib1g-dev \
    gcc-multilib \
    g++-multilib \
    libc6-dev-i386 \
    libncurses5 \
    lib32ncurses5-dev \
    x11proto-core-dev \
    libx11-dev \
    lib32z1-dev \
    libgl1-mesa-dev \
    libxml2-utils \
    xsltproc \
    unzip \
    fontconfig \
    python3 \
    python3-pip \
    python-is-python3 \
    openjdk-8-jdk \
    bc \
    rsync \
    ccache \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Set Java 8 as default
ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
RUN update-alternatives --install /usr/bin/java java ${JAVA_HOME}/bin/java 1
RUN update-alternatives --install /usr/bin/javac javac ${JAVA_HOME}/bin/javac 1

# Create user for AOSP development
RUN useradd -m -s /bin/bash aosp && \
    echo "aosp ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to aosp user
USER aosp
WORKDIR /home/aosp

# Configure git (required for repo)
RUN git config --global user.name "AOSP Builder" && \
    git config --global user.email "aosp@builder.local" && \
    git config --global color.ui auto

# Download and install repo tool
RUN mkdir -p ~/.local/bin && \
    curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.local/bin/repo && \
    chmod a+rx ~/.local/bin/repo
ENV PATH="/home/aosp/.local/bin:${PATH}"

# Set up ccache for faster builds
RUN ccache -M 50G
ENV USE_CCACHE=1
ENV CCACHE_DIR=/home/aosp/.ccache

# Create workspace directory
RUN mkdir -p /home/aosp/aosp
WORKDIR /home/aosp/aosp

# Initialize repo (this layer can be cached)
RUN repo init -u https://android.googlesource.com/platform/manifest -b android-12.1.0_r27

# Set environment variables to ensure output is visible during build
ENV PYTHONUNBUFFERED=1

# Create sync script and perform initial repo sync
RUN echo '#!/bin/bash\n \
set -o errexit\n \
set -o nounset\n \
set -o pipefail\n \
set -o xtrace\n \
echo "Syncing repository changes..."\n \
repo sync --jobs=$(nproc) --verbose --current-branch --no-tags\n \
echo "Sync completed!"' > /home/aosp/sync_aosp.sh && \
    chmod +x /home/aosp/sync_aosp.sh

# # Perform initial repo sync
# RUN /home/aosp/sync_aosp.sh    

COPY ./board_config.mk.patch /home/aosp/

ENV ART_BOOT_IMAGE_EXTRA_ARGS="--runtime-arg -Xms32m --runtime-arg -Xmx512m"
ENV WITH_DEXPREOPT=false

# # Set up build environment
# ENV ANDROID_BUILD_TOP=/home/aosp/aosp
# ENV ANDROID_PRODUCT_OUT=/home/aosp/aosp/out/target/product/generic_x86_64

# SHELL ["/bin/bash", "-c"]
#
# RUN source build/envsetup.sh \
#     && lunch aosp_arm64-eng \
#     && m

CMD /bin/bash -c 'cat << "EOF"
🚀 AOSP Build Environment Ready!

Instructions:
1. Sync AOSP source: `~/sync_aosp.sh`
2. Patch to enable WITH_DEXPREOPT environment variable: `git apply --directory build/make ~/board_config.mk.patch`
3. Setup the rest of the build environment: `source/envsetup.sh`
4. Setup build target: `lunch aosp_arm64-eng`
5. Build! `m`

Quick commands:
  ~/sync_aosp.sh
  git apply --directory build/make ~/board_config.mk.patch
  source build/envsetup.sh
  lunch aosp_arm64-eng
  m

EOF
exec bash'

# Build instructions:
# 1. Build the image: docker build -t aosp-builder .
# 2. Run container: docker run -it --name aosp-build -v aosp-ccache:/home/aosp/.ccache aosp-builder
# 3. Inside container, run: ./build_aosp.sh (for full build)
# 4. For updates, run: ./sync_aosp.sh && ./build_aosp.sh
#
# To persist builds across container restarts:
# docker run -it --name aosp-build -v aosp-source:/home/aosp/aosp -v aosp-ccache:/home/aosp/.ccache aosp-builder
#
# Memory requirements: At least 16GB RAM recommended, 32GB+ preferred
# Disk space: At least 400GB free space required