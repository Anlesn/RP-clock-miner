#!/bin/bash
# Bitcoin Core setup script for Raspberry Pi 5 solo mining
# Automates the entire node preparation process

# Exit immediately if any command fails
# This ensures we don't continue with a broken setup
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

echo "╔════════════════════════════════════════════╗"
echo "║     Bitcoin Solo Mining Node Setup         ║"
echo "║         for Raspberry Pi 5                 ║"
echo "╚════════════════════════════════════════════╝"
echo

# Check if running on Raspberry Pi
# /proc/device-tree/model contains device model information
if [[ -f /proc/device-tree/model ]] && grep -q "Raspberry Pi" /proc/device-tree/model; then
    echo "[✓] Running on Raspberry Pi"
else
    # Warn if not on RPi - some commands may not work
    echo "[!] Warning: Not running on Raspberry Pi. Some optimizations may not apply."
fi

# Check CPU architecture
ARCH=$(uname -m)
echo "[*] Detected architecture: $ARCH"

# Verify it's ARM64 (aarch64)
if [ "$ARCH" != "aarch64" ] && [ "$ARCH" != "arm64" ]; then
    echo -e "${RED}[!] ERROR: This script is designed for ARM64 (aarch64) architecture${NC}"
    echo -e "${RED}    Detected: $ARCH${NC}"
    echo -e "${YELLOW}    Bitcoin Core ARM64 binaries won't work on this system.${NC}"
    echo
    echo "Options:"
    echo "  1. If you're on x86_64, modify the script to download x86_64 binaries"
    echo "  2. Use the official Bitcoin Core installation for your platform"
    echo
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
fi

echo "[*] Updating system packages..."
sudo apt update
sudo apt upgrade -y

echo "[*] Installing dependencies..."
# Install all required packages (except Bitcoin Core):
sudo apt install -y \
    htop \
    python3-pip \
    git \
    build-essential \
    autoconf \
    automake \
    libssl-dev \
    libcurl4-openssl-dev \
    libjansson-dev \
    libgmp-dev \
    zlib1g-dev \
    libnuma-dev \
    screen \
    curl \
    wget \
    jq \
    bc

echo "[*] Installing Bitcoin Core..."
# Get latest Bitcoin Core version
echo "[*] Checking latest Bitcoin Core version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/bitcoin/bitcoin/releases/latest | jq -r '.tag_name' | sed 's/v//')
if [ -z "$LATEST_VERSION" ]; then
    echo "[!] Failed to get latest version, using fallback"
    BITCOIN_VERSION="28.1"
else
    BITCOIN_VERSION="$LATEST_VERSION"
fi
echo "[*] Installing Bitcoin Core ${BITCOIN_VERSION}..."

# Determine correct Bitcoin Core binary for architecture
case "$ARCH" in
    aarch64|arm64)
        BITCOIN_ARCH="aarch64-linux-gnu"
        echo "[*] Using ARM64 binary"
        ;;
    x86_64)
        BITCOIN_ARCH="x86_64-linux-gnu"
        echo "[*] Using x86_64 binary"
        ;;
    *)
        echo -e "${RED}[!] Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

# Download Bitcoin Core for detected architecture
BITCOIN_URL="https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}.tar.gz"
BITCOIN_SHA256="https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS"

cd /tmp
echo "[*] Downloading Bitcoin Core ${BITCOIN_VERSION}..."
wget -q --show-progress "$BITCOIN_URL"

# Verify checksum
echo "[*] Verifying download integrity..."
wget -q "$BITCOIN_SHA256"
DOWNLOADED_HASH=$(sha256sum bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}.tar.gz | awk '{print $1}')
if grep -q "$DOWNLOADED_HASH" SHA256SUMS; then
    echo "[✓] Checksum verified"
else
    echo -e "${RED}[!] Checksum verification failed! Aborting.${NC}"
    echo "Expected hash to be in SHA256SUMS file"
    echo "Downloaded file hash: $DOWNLOADED_HASH"
    exit 1
fi

# Extract and install
echo "[*] Installing Bitcoin Core..."
tar -xzf bitcoin-${BITCOIN_VERSION}-${BITCOIN_ARCH}.tar.gz
sudo cp -r bitcoin-${BITCOIN_VERSION}/bin/* /usr/local/bin/
sudo chmod +x /usr/local/bin/bitcoin*

# Clean up
rm -rf bitcoin-${BITCOIN_VERSION}*
cd -

echo "[✓] Bitcoin Core ${BITCOIN_VERSION} installed"

echo "[*] Detecting system resources..."
# Detect RAM size
RAM_SIZE=$(free -m | awk 'NR==2{print $2}')
echo "Detected RAM: ${RAM_SIZE}MB"

echo "[*] Setting up swap for better performance..."
# Swap provides virtual memory on disk when RAM is insufficient
# Essential for blockchain sync and compilation processes

# Determine optimal settings based on RAM
if [ $RAM_SIZE -lt 4500 ]; then
    # 4GB model
    SWAP_SIZE="4G"
    DB_CACHE="1500"  # Higher value for faster initial sync
    echo "Configuring for 4GB Raspberry Pi 5"
    echo "Note: dbcache=1500 for fast sync. Can reduce to 450 after sync completes."
else
    # 8GB model
    SWAP_SIZE="2G"
    DB_CACHE="2500"  # Higher value for faster initial sync
    echo "Configuring for 8GB Raspberry Pi 5"
    echo "Note: dbcache=2500 for fast sync. Can reduce to 1000 after sync completes."
fi

echo "Setting swap size: $SWAP_SIZE"

echo "[*] Creating Bitcoin data directory..."
# Create Bitcoin data directory if it doesn't exist
# -p flag creates parent directories as needed
mkdir -p ~/.bitcoin

# Copy our configuration file to standard location
# $(dirname "$0") is the directory where this script is located
cp "$(dirname "$0")/bitcoin.conf" ~/.bitcoin/bitcoin.conf

# Optimize bitcoin.conf based on available RAM
echo "[*] Optimizing Bitcoin Core configuration..."
sed -i "s/dbcache=.*/dbcache=$DB_CACHE/" ~/.bitcoin/bitcoin.conf
echo "[✓] Set dbcache to ${DB_CACHE}MB for optimal performance"

# Check if swap file already exists
if ! grep -q "swapfile" /etc/fstab; then
    # Create swap file with optimal size
    sudo fallocate -l $SWAP_SIZE /swapfile
    
    # Set permissions to 600 (only root can read/write)
    # This is important for security
    sudo chmod 600 /swapfile
    
    # Format file as swap
    sudo mkswap /swapfile
    
    # Activate swap immediately
    sudo swapon /swapfile
    
    # Add to fstab for automatic activation on boot
    # sw 0 0 are standard swap parameters
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    echo "[✓] $SWAP_SIZE swap file created"
else
    echo "[✓] Swap already configured"
fi

echo
echo "╔════════════════════════════════════════════╗"
echo "║         Setup Complete!                    ║"
echo "╚════════════════════════════════════════════╝"
echo
echo -e "${GREEN}Bitcoin Core installed successfully!${NC}"
echo "Your node will use pruned mode (~5GB storage)"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Configure your mining credentials (if not done yet):"
echo "   bash secrets/generate_secrets.sh"
echo "   bash secrets/set_secrets.sh"
echo
echo "2. Set up autostart service:"
echo "   bash system/install_autostart.sh"
echo
echo "3. Start mining:"
echo "   sudo systemctl start rp-clock-miner"
echo
echo -e "${BLUE}Note:${NC}"
echo "- Bitcoin Core will start automatically with the service"
echo "- Initial sync takes 12-24 hours. Check progress:"
echo "  bitcoin-cli getblockchaininfo"
echo
echo "Happy solo mining! May the odds be ever in your favor 🎰"