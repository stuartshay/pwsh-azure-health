# Use the official PowerShell image as base
ARG VARIANT="7.5.4-ubuntu-22.04"
FROM mcr.microsoft.com/powershell:${VARIANT}

# Install common dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    python3 \
    python3-pip \
    python3-venv \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Create a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for Azure Functions Core Tools)
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Note: Azure Functions Core Tools will be installed via npm in postCreateCommand

# Set the default user
USER $USERNAME

# Set working directory
WORKDIR /workspace

# Set PowerShell as the default shell
ENV SHELL=/usr/bin/pwsh
