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

# Download Bitcoin Core for ARM64
BITCOIN_URL="https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/bitcoin-${BITCOIN_VERSION}-aarch64-linux-gnu.tar.gz"
BITCOIN_SHA256="https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS"

cd /tmp
echo "[*] Downloading Bitcoin Core ${BITCOIN_VERSION}..."
wget -q --show-progress "$BITCOIN_URL"

# Verify checksum
echo "[*] Verifying download integrity..."
wget -q "$BITCOIN_SHA256"
if grep -q $(sha256sum bitcoin-${BITCOIN_VERSION}-aarch64-linux-gnu.tar.gz | awk '{print $1}') SHA256SUMS; then
    echo "[✓] Checksum verified"
else
    echo "[!] Checksum verification failed! Aborting."
    exit 1
fi

# Extract and install
echo "[*] Installing Bitcoin Core..."
tar -xzf bitcoin-${BITCOIN_VERSION}-aarch64-linux-gnu.tar.gz
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
    DB_CACHE="450"
    echo "Configuring for 4GB Raspberry Pi 5"
else
    # 8GB model
    SWAP_SIZE="2G"
    DB_CACHE="1000"
    echo "Configuring for 8GB Raspberry Pi 5"
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
echo "Next steps:"
echo "1. Start Bitcoin Core: bitcoind -daemon"
echo "   (-daemon runs the process in background)"
echo
echo "2. Wait for initial sync (this will take time)"
echo "   Initial sync can take 12-24 hours!"
echo "   Check progress: bitcoin-cli getblockchaininfo"
echo
echo "3. Configure your mining address:"
echo "   Run: bash secrets/generate_secrets.sh"
echo "   Enter your Bitcoin address (use hardware wallet for security!)"
echo
echo "4. Apply configuration:"
echo "   Run: bash secrets/set_secrets.sh"
echo "   This will configure the miner with your address"
echo
echo "Your node will use pruned mode (~5GB storage)"
echo "Instead of 500+ GB, only 5GB will be used"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. (Optional, not implemented yet) Install Python dependencies: pip3 install -r display/requirements.txt"
echo "2. Set up autostart: bash system/install_autostart.sh"
echo
echo "Happy solo mining! May the odds be ever in your favor 🎰"
echo "Remember: chances are minimal, but they exist!"