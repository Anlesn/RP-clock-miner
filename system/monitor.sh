#!/bin/bash
# Monitoring script that runs via cron to ensure everything is healthy
# Add to crontab: */5 * * * * /home/user/RP-clock-miner/system/monitor.sh

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ALERT_FILE="/tmp/rp-miner-alert"

# Function to log (logs go to syslog/journalctl)
log() {
    logger -t rp-clock-miner-monitor "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to send alert (implement email/telegram if configured)
send_alert() {
    local message="$1"
    echo "$message" > "$ALERT_FILE"
    log "ALERT: $message"
    
    # If email configured in .env
    if [ -f "$PROJECT_DIR/.env" ]; then
        source "$PROJECT_DIR/.env"
        if [ -n "$NOTIFICATION_EMAIL" ]; then
            echo "$message" | mail -s "RP-Miner Alert" "$NOTIFICATION_EMAIL" 2>/dev/null || true
        fi
    fi
}

# Check if service is running
if ! systemctl is-active --quiet rp-clock-miner; then
    log "WARNING: Service not running, attempting restart..."
    sudo systemctl start rp-clock-miner
    sleep 10
    
    if ! systemctl is-active --quiet rp-clock-miner; then
        send_alert "RP-Miner service failed to start!"
    fi
fi

# Check temperature (read threshold from config)
CONFIG_FILE="$PROJECT_DIR/miner/config.json"
if [ -f "$CONFIG_FILE" ]; then
    TEMP_CRITICAL=$(grep -o '"temperature_critical":[[:space:]]*[0-9]*' "$CONFIG_FILE" | grep -o '[0-9]*$' || echo "80")
else
    TEMP_CRITICAL=80
fi

temp=$(vcgencmd measure_temp | grep -o '[0-9]*\.[0-9]*' || echo "0")
if (( $(echo "$temp > $TEMP_CRITICAL" | bc -l) )); then
    send_alert "Critical temperature: ${temp}°C (threshold: ${TEMP_CRITICAL}°C)"
fi

# Check disk space
DISK_WARNING_PERCENT=90
disk_usage=$(df -h / | awk 'NR==2 {print int($5)}')
if [ "$disk_usage" -gt $DISK_WARNING_PERCENT ]; then
    send_alert "Low disk space: ${disk_usage}% used (threshold: ${DISK_WARNING_PERCENT}%)"
fi

# Check if Bitcoin Core is responsive
if pgrep -f "bitcoind" > /dev/null; then
    if ! timeout 10 bitcoin-cli getblockcount > /dev/null 2>&1; then
        log "WARNING: Bitcoin Core not responding"
        send_alert "Bitcoin Core is running but not responding"
    fi
fi

# Log current status
blocks=$(bitcoin-cli getblockcount 2>/dev/null || echo "Unknown")
hashrate=$(curl -s http://127.0.0.1:4048/summary 2>/dev/null | grep -o '"KHS":[0-9.]*' | cut -d: -f2 || echo "0")

log "Status: Blocks=$blocks, Hashrate=${hashrate}KH/s, Temp=${temp}°C, Disk=${disk_usage}%"

# Log rotation is handled by journalctl automatically


