# Use the official PowerShell image as base
# Valid tags: lts-ubuntu-22.04, ubuntu-22.04, 7.4-ubuntu-22.04, latest
ARG VARIANT="lts-ubuntu-22.04"
FROM mcr.microsoft.com/powershell:${VARIANT}

# Note: Most dependencies are installed via Dev Container Features:
# - common-utils: git, curl, wget, ca-certificates, non-root user (vscode)
# - python: Python 3, pip, venv
# - node: Node.js (for Azure Functions Core Tools)
# - azure-cli: Azure CLI
# - dotnet: .NET SDK

# Set PowerShell as the default shell
ENV SHELL=/usr/bin/pwsh
