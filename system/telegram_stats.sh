#!/bin/bash
# Telegram mining statistics reporter
# Sends detailed mining stats to Telegram

# Get project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

# Check if Telegram is configured
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    # Silently exit if not configured (normal for users without Telegram)
    exit 0
fi

# Check if Telegram stats are enabled in config.json
TELEGRAM_INTERVAL=30
if [ -f "$PROJECT_DIR/miner/config.json" ]; then
    if command -v jq >/dev/null 2>&1; then
        TELEGRAM_INTERVAL=$(jq -r '.telegram.stats_interval_minutes // 30' "$PROJECT_DIR/miner/config.json")
    else
        TELEGRAM_INTERVAL=$(grep -o '"stats_interval_minutes":[[:space:]]*[0-9]*' "$PROJECT_DIR/miner/config.json" | grep -o '[0-9]*' || echo "30")
    fi
fi

# Exit if disabled (interval = 0)
if [ "$TELEGRAM_INTERVAL" -eq 0 ]; then
    exit 0
fi

# Collect system statistics
get_stats() {
    # Bitcoin Core status
    if bitcoin-cli getblockchaininfo >/dev/null 2>&1; then
        if command -v jq >/dev/null 2>&1; then
            BLOCKCHAIN_INFO=$(bitcoin-cli getblockchaininfo 2>/dev/null)
            BLOCKS=$(echo "$BLOCKCHAIN_INFO" | jq -r '.blocks // 0')
            HEADERS=$(echo "$BLOCKCHAIN_INFO" | jq -r '.headers // 0')
        else
            BLOCKS=$(bitcoin-cli getblockcount 2>/dev/null || echo "0")
            HEADERS=$(bitcoin-cli getblockchaininfo 2>/dev/null | grep -o '"headers":[[:space:]]*[0-9]*' | grep -o '[0-9]*$' || echo "0")
        fi
        
        # Clean and validate
        BLOCKS=$(echo "$BLOCKS" | tr -d '[:space:]')
        HEADERS=$(echo "$HEADERS" | tr -d '[:space:]')
        BLOCKS=${BLOCKS:-0}
        HEADERS=${HEADERS:-0}
        
        # Calculate percentage only if we have valid numbers
        if [ "$HEADERS" -gt 0 ] && [ "$BLOCKS" != "N/A" ]; then
            SYNC_PERCENT=$((BLOCKS * 100 / HEADERS))
        else
            SYNC_PERCENT="N/A"
        fi
        
        BITCOIN_STATUS="✅ Running"
    else
        BITCOIN_STATUS="❌ Not running"
        BLOCKS="N/A"
        HEADERS="N/A"
        SYNC_PERCENT="N/A"
    fi
    
    # Mining status (via API)
    MINER_API=$(curl -s http://127.0.0.1:4048/summary 2>/dev/null)
    if [ -n "$MINER_API" ]; then
        HASHRATE=$(echo "$MINER_API" | grep -o '"KHS":[0-9.]*' | cut -d: -f2)
        if [ -n "$HASHRATE" ]; then
            HASHRATE="${HASHRATE} KH/s"
            MINER_STATUS="✅ Mining"
        else
            HASHRATE="N/A"
            MINER_STATUS="⏸️ Waiting"
        fi
        
        ACCEPTED=$(echo "$MINER_API" | grep -o '"ACC":[0-9]*' | cut -d: -f2 || echo "0")
        REJECTED=$(echo "$MINER_API" | grep -o '"REJ":[0-9]*' | cut -d: -f2 || echo "0")
    else
        MINER_STATUS="❌ Not running"
        HASHRATE="N/A"
        ACCEPTED="0"
        REJECTED="0"
    fi
    
    # System info
    TEMP=$(vcgencmd measure_temp 2>/dev/null | grep -o '[0-9]*\.[0-9]*' || echo "N/A")
    UPTIME=$(uptime -p | sed 's/up //')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}')
    
    # Network difficulty
    DIFFICULTY=$(bitcoin-cli getmininginfo 2>/dev/null | grep -o '"difficulty":[0-9.]*' | cut -d: -f2 || echo "N/A")
    
    # BTC price (optional)
    BTC_PRICE=$(curl -s "https://api.coinbase.com/v2/exchange-rates?currency=BTC" 2>/dev/null | \
                grep -o '"USD":"[0-9.]*"' | cut -d'"' -f4 || echo "N/A")
}

# Format message for Telegram
format_message() {
    cat << EOF
<b>🎰 RP Solo Miner Stats</b>

<b>⛏️ Mining Status:</b>
Status: ${MINER_STATUS}
Hashrate: ${HASHRATE}
Shares: ✅${ACCEPTED} / ❌${REJECTED}

<b>⛓️ Bitcoin Core:</b>
Status: ${BITCOIN_STATUS}
Blocks: ${BLOCKS} / ${HEADERS}
Sync: ${SYNC_PERCENT}%
Difficulty: ${DIFFICULTY}

<b>💰 Bitcoin Price:</b>
\$${BTC_PRICE} USD

<b>🖥️ System:</b>
Temperature: ${TEMP}°C
Memory: ${MEM_USED} / ${MEM_TOTAL}
Disk: ${DISK_USED} / ${DISK_TOTAL} (${DISK_PERCENT})
Uptime: ${UPTIME}

<i>Time: $(date '+%Y-%m-%d %H:%M:%S')</i>
EOF
}

# Main execution
get_stats
MESSAGE=$(format_message)

# Send via telegram_notify.sh
bash "$SCRIPT_DIR/telegram_notify.sh" "$MESSAGE"

