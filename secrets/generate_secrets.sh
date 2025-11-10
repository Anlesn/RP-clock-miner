#!/bin/bash
# Simple secrets generation script
# Allows using pre-defined or generated credentials

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Generating Bitcoin Miner Secrets      ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo

# Check if .env already exists
if [ -f ".env" ]; then
    echo -e "${YELLOW}[!] .env file already exists${NC}"
    echo "Do you want to overwrite it? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Keeping existing configuration."
        exit 0
    fi
fi

echo "Choose secrets generation method:"
echo
echo "1) Use pre-defined secrets (simplest)"
echo "2) Generate secure random password"
echo "3) Enter custom secrets"
echo
read -p "Select option (1-3): " choice

case $choice in
    1)
        echo -e "\n${GREEN}Using pre-defined credentials...${NC}"
        RPC_USER="rpiminer"
        RPC_PASSWORD="raspberry_solo_mining_2024"
        echo -e "${YELLOW}Note: Change the password for production use!${NC}"
        ;;
    
    2)
        echo -e "\n${GREEN}Generating secure credentials...${NC}"
        RPC_USER="rpiminer"
        RPC_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
        echo "Generated password: $RPC_PASSWORD"
        echo -e "${YELLOW}Save this password! You won't see it again.${NC}"
        ;;
    
    3)
        echo -e "\n${GREEN}Enter custom credentials...${NC}"
        read -p "RPC Username [rpiminer]: " custom_user
        RPC_USER=${custom_user:-rpiminer}
        
        echo "RPC Password (min 8 characters):"
        read -s custom_pass
        echo
        
        if [ ${#custom_pass} -lt 8 ]; then
            echo -e "${YELLOW}[!] Password too short, generating secure one...${NC}"
            RPC_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
            echo "Generated password: $RPC_PASSWORD"
        else
            RPC_PASSWORD="$custom_pass"
        fi
        ;;
    
    *)
        echo "Invalid option!"
        exit 1
        ;;
esac

# Get Bitcoin address
echo
echo "Enter your Bitcoin address for mining rewards:"
echo "(Leave empty to generate a new one later)"
read -p "Bitcoin address: " BTC_ADDRESS

if [ -z "$BTC_ADDRESS" ]; then
    BTC_ADDRESS="YOUR_BITCOIN_ADDRESS_HERE"
    echo -e "${YELLOW}[!] No address provided. You'll need to set it later!${NC}"
else
    # Basic validation (just length check)
    if [ ${#BTC_ADDRESS} -lt 26 ] || [ ${#BTC_ADDRESS} -gt 62 ]; then
        echo -e "${YELLOW}[!] Warning: Address looks invalid. Please verify!${NC}"
    fi
fi

# Get WiFi credentials (optional)
echo
echo -e "${BLUE}WiFi Configuration (optional)${NC}"
echo "Enter WiFi credentials for automatic connection:"
read -p "WiFi SSID (network name) [skip]: " WIFI_SSID
if [ -n "$WIFI_SSID" ]; then
    echo "WiFi Password:"
    read -s WIFI_PASSWORD
    echo
    # Basic validation
    if [ ${#WIFI_PASSWORD} -lt 8 ]; then
        echo -e "${YELLOW}[!] Warning: WiFi password seems too short${NC}"
    fi
else
    WIFI_SSID=""
    WIFI_PASSWORD=""
    echo -e "${YELLOW}[!] Skipping WiFi configuration${NC}"
fi

# Create .env file
cat > .env << EOF
# Bitcoin Miner Secrets
# Generated: $(date)

# RPC Authentication
BITCOIN_RPC_USER=$RPC_USER
BITCOIN_RPC_PASSWORD=$RPC_PASSWORD

# Mining Rewards Address
BITCOIN_MINING_ADDRESS=$BTC_ADDRESS

# WiFi Configuration
WIFI_SSID=$WIFI_SSID
WIFI_PASSWORD=$WIFI_PASSWORD

# Optional notifications (add if needed)
NOTIFICATION_EMAIL=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
EOF

# Set secure permissions
chmod 600 .env

echo
echo -e "${GREEN}✅ Secrets saved to .env${NC}"
echo
echo "Summary:"
echo "  RPC User: $RPC_USER"
echo "  RPC Pass: ${RPC_PASSWORD:0:6}***${RPC_PASSWORD: -4}"
echo "  BTC Addr: $BTC_ADDRESS"
if [ -n "$WIFI_SSID" ]; then
    echo "  WiFi Net: $WIFI_SSID"
fi
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Run: bash secrets/set_secrets.sh"
echo "2. Start installation: ./install.sh"
echo
echo -e "${GREEN}Important: Keep .env file secure and never commit to git!${NC}"
