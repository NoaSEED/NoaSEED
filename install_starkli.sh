#!/bin/bash

# Install Starkli - Alternative Methods
# Instala starkli usando métodos alternativos si cargo falla

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
progress() { echo -e "${BLUE}==> $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }

echo -e "${BLUE}🔧 Install Starkli - Alternative Methods${NC}"
echo ""

# Check if starkli is already installed
if command -v starkli &> /dev/null; then
    log "✅ Starkli is already installed"
    starkli --version
    exit 0
fi

# Method 1: Try installing with specific Rust version
progress "Method 1: Installing with specific Rust version..."
if command -v rustc &> /dev/null; then
    log "Rust is available, trying starkli installation..."
    
    # Try different approaches
    if cargo install starkli --version 0.1.7 --locked; then
        log "✅ Starkli installed successfully with version 0.1.7"
        exit 0
    fi
    
    if cargo install starkli --no-default-features --features cli; then
        log "✅ Starkli installed successfully with CLI features only"
        exit 0
    fi
    
    if cargo install starkli --git https://github.com/xJonathanLEI/starkli.git; then
        log "✅ Starkli installed successfully from git"
        exit 0
    fi
fi

# Method 2: Install from pre-built binary
progress "Method 2: Installing from pre-built binary..."
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

if [[ "$ARCH" == "x86_64" ]]; then
    ARCH="amd64"
elif [[ "$ARCH" == "aarch64" ]]; then
    ARCH="arm64"
fi

# Download pre-built binary
STARKLI_VERSION="0.1.7"
DOWNLOAD_URL="https://github.com/xJonathanLEI/starkli/releases/download/v${STARKLI_VERSION}/starkli-${STARKLI_VERSION}-${OS}-${ARCH}"

log "Downloading starkli from: $DOWNLOAD_URL"
if curl -L -o /tmp/starkli "$DOWNLOAD_URL"; then
    chmod +x /tmp/starkli
    sudo mv /tmp/starkli /usr/local/bin/starkli
    log "✅ Starkli installed from pre-built binary"
    starkli --version
    exit 0
fi

# Method 3: Use alternative Starknet CLI
progress "Method 3: Installing alternative Starknet CLI..."
if command -v pip3 &> /dev/null; then
    if pip3 install starknet-devnet; then
        log "✅ Installed starknet-devnet as alternative"
        log "Note: Using starknet-devnet instead of starkli"
        exit 0
    fi
fi

# Method 4: Manual installation
progress "Method 4: Manual installation from source..."
if command -v git &> /dev/null && command -v cargo &> /dev/null; then
    cd /tmp
    git clone https://github.com/xJonathanLEI/starkli.git
    cd starkli
    cargo build --release
    sudo cp target/release/starkli /usr/local/bin/
    log "✅ Starkli built and installed from source"
    starkli --version
    exit 0
fi

warn "❌ All installation methods failed"
warn "You may need to install starkli manually or use an alternative"
echo ""
echo -e "${YELLOW}Alternative options:${NC}"
echo "1. Use Starknet CLI: pip3 install starknet-devnet"
echo "2. Use online tools for wallet creation"
echo "3. Install starkli manually from: https://github.com/xJonathanLEI/starkli"
echo ""
exit 1
