#!/bin/bash
# Complete autostart installation script
# Sets up systemd service, cron monitoring, and recovery mechanisms

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Installing Autostart & Recovery System  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo

# Get project directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER=$(whoami)

# 1. Make all scripts executable
echo -e "${YELLOW}[*] Setting script permissions...${NC}"
chmod +x "$PROJECT_DIR/system"/*.sh
chmod +x "$PROJECT_DIR/miner"/*.sh
chmod +x "$PROJECT_DIR/secrets"/*.sh

# 2. Update paths in service file
echo -e "${YELLOW}[*] Configuring systemd service...${NC}"
sed -e "s|/home/pi/RP-clock-miner|$PROJECT_DIR|g" \
    -e "s|/home/pi/.bitcoin|$HOME/.bitcoin|g" \
    -e "s|User=pi|User=$USER|g" \
    -e "s|Group=pi|Group=$USER|g" \
    "$PROJECT_DIR/system/autostart.service" > /tmp/rp-clock-miner.service

# 3. Install systemd service
echo -e "${YELLOW}[*] Installing systemd service...${NC}"
sudo cp /tmp/rp-clock-miner.service /etc/systemd/system/
sudo systemctl daemon-reload

# 4. Enable service
echo -e "${YELLOW}[*] Enabling autostart service...${NC}"
sudo systemctl enable rp-clock-miner.service

# 5. Set up log rotation
echo -e "${YELLOW}[*] Setting up log rotation...${NC}"
cat > /tmp/rp-clock-miner-logrotate << EOF
/var/log/rp-clock-miner*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 $USER $USER
    postrotate
        systemctl reload rp-clock-miner 2>/dev/null || true
    endscript
}
EOF

sudo cp /tmp/rp-clock-miner-logrotate /etc/logrotate.d/rp-clock-miner

# 6. Set up cron monitoring
echo -e "${YELLOW}[*] Setting up monitoring cron job...${NC}"
(crontab -l 2>/dev/null | grep -v "rp-clock-miner/system/monitor.sh" || true
 echo "*/5 * * * * $PROJECT_DIR/system/monitor.sh") | crontab -

# 7. Enable Bitcoin Core autostart
echo -e "${YELLOW}[*] Configuring Bitcoin Core autostart...${NC}"
cat > /tmp/bitcoind.service << EOF
[Unit]
Description=Bitcoin Core Daemon
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/bitcoind -daemon -conf=$HOME/.bitcoin/bitcoin.conf -datadir=$HOME/.bitcoin
ExecStop=/usr/local/bin/bitcoin-cli stop
Restart=on-failure
User=$USER
Group=$USER

[Install]
WantedBy=multi-user.target
EOF

sudo cp /tmp/bitcoind.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable bitcoind

# 8. Create startup verification script
echo -e "${YELLOW}[*] Creating verification script...${NC}"
cat > "$PROJECT_DIR/system/verify_autostart.sh" << 'EOF'
#!/bin/bash
# Verify autostart is properly configured

echo "Checking autostart configuration..."

# Check systemd service
if systemctl is-enabled rp-clock-miner.service 2>/dev/null; then
    echo "✓ Systemd service is enabled"
else
    echo "✗ Systemd service not enabled"
fi

if systemctl is-active --quiet rp-clock-miner.service; then
    echo "✓ Service is currently running"
else
    echo "✗ Service is not running"
fi

# Check cron
if crontab -l | grep -q "monitor.sh"; then
    echo "✓ Monitoring cron job installed"
else
    echo "✗ Monitoring cron job missing"
fi

# Check logs
if [ -f /var/log/rp-clock-miner.log ]; then
    echo "✓ Log file exists"
    echo "  Recent entries:"
    tail -n 5 /var/log/rp-clock-miner.log | sed 's/^/    /'
else
    echo "✗ No log file found"
fi

# Test restart capability
echo
echo "Testing restart capability..."
sudo systemctl restart rp-clock-miner
sleep 5
if systemctl is-active --quiet rp-clock-miner; then
    echo "✓ Service restarted successfully"
else
    echo "✗ Service failed to restart"
fi
EOF

chmod +x "$PROJECT_DIR/system/verify_autostart.sh"

# 9. Create uninstall script
echo -e "${YELLOW}[*] Creating uninstall script...${NC}"
cat > "$PROJECT_DIR/system/uninstall_autostart.sh" << EOF
#!/bin/bash
# Uninstall autostart components

echo "Removing autostart configuration..."

# Stop and disable service
sudo systemctl stop rp-clock-miner
sudo systemctl disable rp-clock-miner
sudo rm -f /etc/systemd/system/rp-clock-miner.service

# Remove cron job
crontab -l | grep -v "rp-clock-miner/system/monitor.sh" | crontab -

# Remove log rotation
sudo rm -f /etc/logrotate.d/rp-clock-miner

# Clean up logs
sudo rm -f /var/log/rp-clock-miner*.log

echo "Autostart removed. Manual startup still available."
EOF

chmod +x "$PROJECT_DIR/system/uninstall_autostart.sh"

# Summary
echo
echo -e "${GREEN}╔═══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Autostart Installation Complete!      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════╝${NC}"
echo
echo "Installed components:"
echo "  ✓ Systemd service with automatic restart"
echo "  ✓ Power failure recovery"
echo "  ✓ Health monitoring (every 5 minutes)"
echo "  ✓ Log rotation (7 days)"
echo
echo -e "${YELLOW}Commands:${NC}"
echo "  Start now:        sudo systemctl start rp-clock-miner"
echo "  View status:      sudo systemctl status rp-clock-miner"
echo "  View logs:        journalctl -u rp-clock-miner -f"
echo "  Verify setup:     ./system/verify_autostart.sh"
echo
echo -e "${GREEN}Your miner will now automatically start on boot!${NC}"
echo -e "${GREEN}It will recover from power failures and crashes.${NC}"
echo
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Start the miner: sudo systemctl start rp-clock-miner"
echo "2. Monitor logs: journalctl -u rp-clock-miner -f"
echo
echo "Setup complete! Your Bitcoin solo miner is ready to run 24/7."


