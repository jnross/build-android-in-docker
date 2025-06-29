FROM ubuntu:22.04

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
RUN repo init -u https://android.googlesource.com/platform/manifest -b android-14.0.0_r1

# Set up build environment
ENV ANDROID_BUILD_TOP=/home/aosp/aosp
ENV ANDROID_PRODUCT_OUT=/home/aosp/aosp/out/target/product/generic_x86_64

# Create build script
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Syncing repository..."\n\
repo sync -j$(nproc)\n\
echo "Setting up build environment..."\n\
source build/envsetup.sh\n\
echo "Selecting build target..."\n\
lunch aosp_x86_64-eng\n\
echo "Starting build..."\n\
m -j$(nproc)\n\
echo "Build completed successfully!"' > /home/aosp/build_aosp.sh && \
    chmod +x /home/aosp/build_aosp.sh

# Create sync script for updates
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Syncing latest changes..."\n\
repo sync -j$(nproc)\n\
echo "Sync completed!"' > /home/aosp/sync_aosp.sh && \
    chmod +x /home/aosp/sync_aosp.sh

# Set default command
CMD ["/bin/bash"]

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