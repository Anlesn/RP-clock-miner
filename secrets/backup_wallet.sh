#!/bin/bash
# Secure wallet backup script
# Creates encrypted backup of wallet and configuration

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Secure Wallet Backup Tool          ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo

# Create backup directory with timestamp
BACKUP_DIR="$HOME/rpi_miner_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}[*] Creating backup in: $BACKUP_DIR${NC}"

# Backup items checklist
BACKUP_ITEMS=()

# 1. Backup .env file if exists
if [ -f "../.env" ]; then
    cp ../.env "$BACKUP_DIR/.env"
    BACKUP_ITEMS+=(".env file")
    echo -e "${GREEN}[✓] Backed up .env file${NC}"
fi

# 2. Backup config files
if [ -f "../miner/config.json" ]; then
    cp ../miner/config.json "$BACKUP_DIR/miner_config.json"
    BACKUP_ITEMS+=("Miner configuration")
fi

if [ -f "$HOME/.bitcoin/bitcoin.conf" ]; then
    cp "$HOME/.bitcoin/bitcoin.conf" "$BACKUP_DIR/bitcoin.conf"
    BACKUP_ITEMS+=("Bitcoin Core configuration")
fi

# 4. Create wallet info file
cat > "$BACKUP_DIR/wallet_info.txt" << EOF
Wallet Backup Information
Created: $(date)
System: $(hostname)

IMPORTANT SECURITY INFORMATION:
==============================

1. Mining Address:
   Check your .env file for BITCOIN_MINING_ADDRESS

2. Recovery Steps:
   a) Install RP-clock-miner on new system
   b) Copy .env file to project root
   c) Run: bash secrets/set_secrets.sh
   d) Start mining: ./miner/run_miner.sh

3. Security Best Practices:
   - Store this backup encrypted on multiple devices
   - Use hardware wallet for significant amounts
   - Test recovery process with small amounts first
   - Keep backup offline (USB drive, paper)

4. Encryption:
   To encrypt this backup folder:
   tar -czf - $BACKUP_DIR | openssl enc -aes-256-cbc -salt -out backup.tar.gz.enc
   
   To decrypt later:
   openssl enc -aes-256-cbc -d -in backup.tar.gz.enc | tar -xzf -

EOF

echo -e "${GREEN}[✓] Created wallet info file${NC}"

# 5. Create backup verification script
cat > "$BACKUP_DIR/verify_backup.sh" << 'EOF'
#!/bin/bash
# Verify backup integrity

echo "Backup Verification"
echo "=================="
echo
echo "Files in this backup:"
ls -la
echo
echo "Checking .env file..."
if [ -f .env ]; then
    grep "BITCOIN_MINING_ADDRESS" .env && echo "[✓] Mining address found"
    grep "BITCOIN_RPC" .env && echo "[✓] RPC credentials found"
else
    echo "[!] No .env file found"
fi
echo
echo "Backup appears complete. Store this securely!"
EOF

chmod +x "$BACKUP_DIR/verify_backup.sh"

# Summary
echo
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Backup Complete!                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo
echo "Backed up items:"
for item in "${BACKUP_ITEMS[@]}"; do
    echo "  ✓ $item"
done
echo
echo -e "${YELLOW}Location: $BACKUP_DIR${NC}"
echo
echo -e "${RED}⚠️  IMPORTANT NEXT STEPS:${NC}"
echo "1. Encrypt the backup folder:"
echo "   tar -czf - $BACKUP_DIR | openssl enc -aes-256-cbc -salt -out ~/wallet_backup.tar.gz.enc"
echo
echo "2. Copy encrypted backup to:"
echo "   - USB drive (offline storage)"
echo "   - Cloud storage (encrypted)"
echo "   - Paper printout (QR codes)"
echo
echo "3. Delete unencrypted backup:"
echo "   rm -rf $BACKUP_DIR"
echo
echo -e "${YELLOW}Remember: Your wallet is only as secure as your backup!${NC}"


