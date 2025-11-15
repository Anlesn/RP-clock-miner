#!/bin/bash
# Script to set secrets using environment variables

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "╔═══════════════════════════════════════════╗"
echo "║                Set Secrets                ║"
echo "╚═══════════════════════════════════════════╝"
echo

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}[!] .env file not found!${NC}"
    echo "Please run: bash secrets/generate_secrets.sh"
    exit 1
fi

# Load environment variables
source .env

# Validate required variables
if [ -z "$BITCOIN_RPC_USER" ] || [ -z "$BITCOIN_RPC_PASSWORD" ] || [ -z "$BITCOIN_MINING_ADDRESS" ]; then
    echo -e "${RED}[!] Missing required environment variables!${NC}"
    echo "Please check your .env file"
    exit 1
fi

# Update bitcoin.conf with values from .env
echo -e "${YELLOW}[*] Updating bitcoin.conf...${NC}"
BITCOIN_CONF="$HOME/.bitcoin/bitcoin.conf"

if [ -f "$BITCOIN_CONF" ]; then
    # Backup existing config
    cp "$BITCOIN_CONF" "$BITCOIN_CONF.backup"
    
    # Update RPC credentials
    sed -i "s/^rpcuser=.*/rpcuser=$BITCOIN_RPC_USER/" "$BITCOIN_CONF"
    sed -i "s/^rpcpassword=.*/rpcpassword=$BITCOIN_RPC_PASSWORD/" "$BITCOIN_CONF"
    
    echo -e "${GREEN}[✓] bitcoin.conf updated${NC}"
else
    echo -e "${YELLOW}[*] Creating bitcoin.conf...${NC}"
    mkdir -p "$HOME/.bitcoin"
    cp node/bitcoin.conf "$BITCOIN_CONF"
    sed -i "s/^rpcuser=.*/rpcuser=$BITCOIN_RPC_USER/" "$BITCOIN_CONF"
    sed -i "s/^rpcpassword=.*/rpcpassword=$BITCOIN_RPC_PASSWORD/" "$BITCOIN_CONF"
fi

# Update miner config.json
echo -e "${YELLOW}[*] Updating miner config...${NC}"
CONFIG_FILE="miner/config.json"

# Note: config.json only has placeholders, real values come from .env
echo -e "${YELLOW}[!] Note: config.json uses placeholders for security${NC}"
echo "    Actual values are loaded from .env at runtime"

# Just verify the config file exists and has correct structure
if ! grep -q "PLACEHOLDER" "$CONFIG_FILE"; then
    echo -e "${YELLOW}[*] Updating config.json to use placeholders...${NC}"
    # Use jq if available, otherwise use sed
    if command -v jq &> /dev/null; then
        # Update config using jq
        jq '.bitcoind.user = "PLACEHOLDER" | .bitcoind.password = "PLACEHOLDER" | .coinbase.address = "PLACEHOLDER"' \
           "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    else
        # Fallback to sed
        sed -i 's/"user": "[^"]*"/"user": "PLACEHOLDER"/' "$CONFIG_FILE"
        sed -i 's/"password": "[^"]*"/"password": "PLACEHOLDER"/' "$CONFIG_FILE"
        sed -i 's/"address": "[^"]*"/"address": "PLACEHOLDER"/' "$CONFIG_FILE"
    fi
fi

echo -e "${GREEN}[✓] Miner config updated${NC}"

# Set proper permissions
echo -e "${YELLOW}[*] Setting secure permissions...${NC}"
chmod 600 .env
chmod 600 "$BITCOIN_CONF" 2>/dev/null || true
chmod 600 "$CONFIG_FILE"

echo
echo -e "${GREEN}✅ Configuration complete!${NC}"
echo
echo "Your setup is now using:"
echo "  RPC User: $BITCOIN_RPC_USER"
echo "  Mining Address: $BITCOIN_MINING_ADDRESS"
echo
echo -e "${YELLOW}⚠️  Security reminders:${NC}"
echo "  - Never share your .env file"
echo "  - Keep backups of your configuration"
echo "  - Use hardware wallet for large amounts"
echo "  - Enable 2FA on your RPi if possible"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Continue with Bitcoin Core setup: bash node/setup_node.sh"
