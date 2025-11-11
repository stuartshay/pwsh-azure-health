#!/bin/bash
#
# Install BATS (Bash Automated Testing System)
# https://github.com/bats-core/bats-core
#

set -e

echo "Installing BATS (Bash Automated Testing System)..."

# Detect OS and install method
if command -v npm &> /dev/null; then
    echo "Using npm to install bats..."
    npm install -g bats
elif command -v brew &> /dev/null; then
    echo "Using Homebrew to install bats..."
    brew install bats-core
elif command -v apt-get &> /dev/null; then
    echo "Installing bats via git clone (Debian/Ubuntu)..."
    git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
    cd /tmp/bats-core
    sudo ./install.sh /usr/local
    cd -
    rm -rf /tmp/bats-core
else
    echo "Installing bats via git clone (generic)..."
    git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-core
    cd /tmp/bats-core
    sudo ./install.sh /usr/local
    cd -
    rm -rf /tmp/bats-core
fi

# Verify installation
if command -v bats &> /dev/null; then
    echo "✅ BATS installed successfully!"
    bats --version
else
    echo "❌ BATS installation failed"
    exit 1
fi

echo ""
echo "Next steps:"
echo "1. Run tests: bats tests/workflows/"
echo "2. Run specific test: bats tests/workflows/retry-utils.bats"
echo "3. See verbose output: bats --tap tests/workflows/retry-utils.bats"
