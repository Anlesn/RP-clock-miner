#!/bin/bash
# Telegram mining statistics reporter
# Sends detailed mining stats to Telegram

# Ensure PATH includes bitcoin-cli and other binaries
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

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
    
    # Mining status
    # Check if cpuminer process is running
    if pgrep -f "cpuminer" > /dev/null 2>&1; then
        # Try to get hashrate from API
        MINER_API=$(curl -s http://127.0.0.1:4048/summary 2>/dev/null)
        if [ -n "$MINER_API" ]; then
            HASHRATE=$(echo "$MINER_API" | grep -o '"KHS":[0-9.]*' | cut -d: -f2)
            if [ -n "$HASHRATE" ] && [ "$HASHRATE" != "0" ]; then
                # API responds with hashrate - actively mining
                HASHRATE="${HASHRATE} KH/s"
                MINER_STATUS="✅ Mining"
            else
                # API responds but no hashrate - waiting for sync
                HASHRATE="N/A"
                MINER_STATUS="⏸️ Waiting for sync"
            fi
        else
            # API not responding - check if blockchain is synced
            if [ "$SYNC_PERCENT" != "N/A" ] && [ "$SYNC_PERCENT" -lt 100 ]; then
                # Not synced - waiting is expected
                HASHRATE="N/A"
                MINER_STATUS="⏸️ Waiting for sync"
            else
                # Synced but API not responding - this is odd
                HASHRATE="N/A"
                MINER_STATUS="⚠️ Running (no API)"
            fi
        fi
        
        # Calculate uptime of miner service
        MINER_UPTIME=$(systemctl show rp-clock-miner -p ActiveEnterTimestamp --value 2>/dev/null)
        if [ -n "$MINER_UPTIME" ]; then
            MINER_START=$(date -d "$MINER_UPTIME" +%s 2>/dev/null || echo "0")
            CURRENT_TIME=$(date +%s)
            MINER_HOURS=$(( (CURRENT_TIME - MINER_START) / 3600 ))
            MINER_RUNTIME="${MINER_HOURS}h"
        else
            MINER_RUNTIME="N/A"
        fi
    else
        MINER_STATUS="❌ Not running"
        HASHRATE="N/A"
        MINER_RUNTIME="N/A"
    fi
    
    # System info
    TEMP=$(vcgencmd measure_temp 2>/dev/null | grep -o '[0-9]*\.[0-9]*' || echo "N/A")
    
    # CPU usage (average over last minute)
    if command -v top >/dev/null 2>&1; then
        # Get idle% and calculate usage%
        CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1 2>/dev/null || echo "0")
        if [ -n "$CPU_IDLE" ] && [ "$CPU_IDLE" != "0" ]; then
            CPU_USAGE=$(awk "BEGIN {printf \"%.1f\", 100 - $CPU_IDLE}")
        else
            # Fallback: use mpstat or calculate from /proc/stat
            CPU_USAGE=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {printf "%.1f", usage}' 2>/dev/null || echo "N/A")
        fi
    else
        CPU_USAGE="N/A"
    fi
    
    UPTIME=$(uptime -p | sed 's/up //')
    MEM_USED=$(free -h | awk '/^Mem:/ {print $3}')
    MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
    DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
    DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}')
    
    # Network difficulty
    DIFFICULTY=$(bitcoin-cli getmininginfo 2>/dev/null | grep -o '"difficulty":[0-9.]*' | cut -d: -f2 || echo "N/A")
    
    # Mining address balance (if address is set)
    if [ -n "$BITCOIN_MINING_ADDRESS" ] && [ "$BITCOIN_MINING_ADDRESS" != "YOUR_BITCOIN_ADDRESS_HERE" ]; then
        # Try to get balance from wallet (only works if address was generated by this node)
        WALLET_BALANCE=$(bitcoin-cli getreceivedbyaddress "$BITCOIN_MINING_ADDRESS" 0 2>/dev/null || echo "")
        
        # If wallet doesn't have this address, try external API
        if [ -z "$WALLET_BALANCE" ] || [ "$WALLET_BALANCE" = "0" ]; then
            # Use blockchain.info API as fallback
            EXT_BALANCE=$(curl -s "https://blockchain.info/q/addressbalance/$BITCOIN_MINING_ADDRESS" 2>/dev/null || echo "")
            if [ -n "$EXT_BALANCE" ] && [ "$EXT_BALANCE" != "0" ]; then
                # Convert satoshis to BTC
                WALLET_BALANCE=$(echo "scale=8; $EXT_BALANCE / 100000000" | bc 2>/dev/null || echo "0")
            else
                WALLET_BALANCE="0"
            fi
        fi
    else
        WALLET_BALANCE="N/A"
    fi
    
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
Runtime: ${MINER_RUNTIME}

<b>⛓️ Bitcoin Core:</b>
Status: ${BITCOIN_STATUS}
Blocks: ${BLOCKS} / ${HEADERS}
Sync: ${SYNC_PERCENT}%
Difficulty: ${DIFFICULTY}

<b>💰 Bitcoin:</b>
Price: \$${BTC_PRICE} USD
Balance: ${WALLET_BALANCE} BTC

<b>🖥️ System:</b>
CPU Usage: ${CPU_USAGE}%
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

