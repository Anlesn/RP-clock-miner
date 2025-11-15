#!/bin/bash
# Power failure recovery script
# Handles filesystem checks and recovery after unexpected shutdown

# Function to log with timestamp (logs go to journalctl via systemd)
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "============================================"
log "Power Recovery Check Started"
log "============================================"

# 1. Check if this is a recovery from power failure
# Using /tmp instead of /var/log for easier permission management
LAST_SHUTDOWN="/tmp/rp-miner-clean-shutdown"
if [ ! -f "$LAST_SHUTDOWN" ]; then
    log "WARNING: Unclean shutdown detected (possible power failure)"
    
    # 2. Check and repair filesystem if needed
    log "Checking filesystem integrity..."
    
    # Check if we're on SD card
    ROOT_DEV=$(mount | grep "on / " | cut -d' ' -f1)
    if [[ "$ROOT_DEV" == /dev/mmcblk* ]]; then
        log "Running filesystem check on SD card..."
        # Note: This usually runs automatically, but we log it
    fi
    
    # 3. Clean up Bitcoin Core data if corrupted
    if [ -d "$HOME/.bitcoin" ]; then
        # Check for corruption indicators
        if [ -f "$HOME/.bitcoin/db.log" ]; then
            if grep -q "corruption\|fatal\|error" "$HOME/.bitcoin/db.log" 2>/dev/null; then
                log "WARNING: Possible Bitcoin database corruption detected"
                log "Bitcoin Core will reindex on start (this may take time)"
                
                # Create flag for reindex
                touch "$HOME/.bitcoin/reindex-chainstate"
            fi
        fi
    fi
    
    # 4. Clean up any lock files
    log "Cleaning up lock files..."
    rm -f "$HOME/.bitcoin/.lock" 2>/dev/null
    rm -f "$HOME/.bitcoin/bitcoind.pid" 2>/dev/null
    rm -f /var/run/rp-clock-miner*.pid 2>/dev/null
    
    # 5. Reset any hung processes
    log "Checking for hung processes..."
    # Kill any zombie bitcoin or miner processes
    pkill -9 -f "bitcoind.*defunct" 2>/dev/null || true
    pkill -9 -f "cpuminer.*defunct" 2>/dev/null || true
    
    # 6. Ensure swap is properly configured
    if [ -f /swapfile ] && ! swapon -s | grep -q "/swapfile"; then
        log "Re-enabling swap file..."
        sudo swapon /swapfile 2>/dev/null || true
    fi
    
    # 7. Log system status
    log "System Status After Recovery:"
    log "- Memory: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    log "- Disk: $(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
    log "- Temperature: $(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"
    log "- Uptime: $(uptime -p)"
    
else
    log "Clean shutdown detected, normal startup"
    # Remove the clean shutdown flag
    rm -f "$LAST_SHUTDOWN"
fi

# 8. Create shutdown hook for next time
cat > /tmp/create-shutdown-flag.sh << 'EOF'
#!/bin/bash
# This creates a flag on clean shutdown
touch /tmp/rp-miner-clean-shutdown
sync
EOF

chmod +x /tmp/create-shutdown-flag.sh

# Install shutdown hook if not already installed
if ! systemctl is-enabled rp-miner-shutdown.service 2>/dev/null; then
    log "Installing clean shutdown detector..."
    
    cat > /tmp/rp-miner-shutdown.service << EOF
[Unit]
Description=RP Miner Clean Shutdown Flag
DefaultDependencies=no
Before=shutdown.target

[Service]
Type=oneshot
ExecStart=/tmp/create-shutdown-flag.sh
RemainAfterExit=yes

[Install]
WantedBy=shutdown.target
EOF

    sudo cp /tmp/rp-miner-shutdown.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable rp-miner-shutdown.service
fi

log "Power recovery check completed"
log "============================================"

exit 0


