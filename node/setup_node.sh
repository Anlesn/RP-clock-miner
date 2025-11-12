#!/bin/bash
# Bitcoin Core setup script for Raspberry Pi 5 solo mining
# Automates the entire node preparation process

# Exit immediately if any command fails
# This ensures we don't continue with a broken setup
set -e

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
# Install all required packages:
sudo apt install -y \
    bitcoind \              # Bitcoin Core daemon
    htop \                  # System monitoring (CPU, memory)
    python3-pip \           # Python package manager for display
    git \                   # To clone cpuminer source code
    build-essential \       # C/C++ compilers for building cpuminer
    autoconf \              # Automatic configuration tools
    automake \              # Makefile generation tools
    libssl-dev \            # Cryptographic libraries
    libcurl4-openssl-dev \ # HTTP library for pool communication
    libjansson-dev \        # JSON parser for configuration
    screen \                # Run processes in background
    bc                      # Calculator for shell scripts

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

# Optimize bitcoin.conf based on available RAM
echo "[*] Optimizing Bitcoin Core configuration..."
sed -i "s/dbcache=.*/dbcache=$DB_CACHE/" ~/.bitcoin/bitcoin.conf
echo "[✓] Set dbcache to ${DB_CACHE}MB for optimal performance"

echo "[*] Creating Bitcoin data directory..."
# Create Bitcoin data directory if it doesn't exist
# -p flag creates parent directories as needed
mkdir -p ~/.bitcoin

# Copy our configuration file to standard location
# $(dirname "$0") is the directory where this script is located
cp "$(dirname "$0")/bitcoin.conf" ~/.bitcoin/bitcoin.conf

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
echo "Happy solo mining! May the odds be ever in your favor 🎰"
echo "Remember: chances are minimal, but they exist!"