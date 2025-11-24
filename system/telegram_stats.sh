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
        # cpuminer API uses plain text protocol (not HTTP)
        # Format: KHS=12484.26;ACC=0;REJ=0;TEMP=51.2
        # Send HTTP GET to trigger response
        if command -v nc >/dev/null 2>&1; then
            MINER_API=$(echo -e "GET /summary HTTP/1.0\r\n\r\n" | nc -w 1 127.0.0.1 4048 2>/dev/null | tr -d '\0')
        else
            MINER_API=""
        fi
        
        if [ -n "$MINER_API" ]; then
            # Parse KHS (kilohash per second) from response
            HASHRATE_KHS=$(echo "$MINER_API" | grep -o "KHS=[0-9.]*" | cut -d= -f2)
            
            if [ -n "$HASHRATE_KHS" ] && [ "$HASHRATE_KHS" != "0" ]; then
                # Convert KH/s to MH/s for readability
                HASHRATE_MHS=$(awk "BEGIN {printf \"%.2f\", $HASHRATE_KHS / 1000}")
                
                # Get number of threads from config
                THREADS=$(grep -o '"threads":[[:space:]]*[0-9]*' "$PROJECT_DIR/miner/config.json" | grep -o '[0-9]*' || echo "4")
                
                HASHRATE="${HASHRATE_MHS} MH/s (${THREADS} threads)"
                MINER_STATUS="✅ Mining"
            else
                HASHRATE="N/A"
                MINER_STATUS="⏸️ Waiting for sync"
            fi
        else
            # Fallback: parse from journal logs
            RECENT_HASHRATE=$(journalctl -u rp-clock-miner --since "5 minutes ago" -n 50 2>/dev/null | \
                             grep "Miner TTF @" | tail -1 | \
                             grep -o "[0-9.]*\s*MH/s" | head -1)
            
            if [ -n "$RECENT_HASHRATE" ]; then
                HASHRATE="$RECENT_HASHRATE"
                MINER_STATUS="✅ Mining"
            elif [ "$SYNC_PERCENT" != "N/A" ] && [ "$SYNC_PERCENT" -lt 100 ]; then
                HASHRATE="N/A"
                MINER_STATUS="⏸️ Waiting for sync"
            else
                HASHRATE="N/A"
                MINER_STATUS="⚠️ Running (no data)"
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
    if command -v jq >/dev/null 2>&1; then
        DIFFICULTY=$(bitcoin-cli getmininginfo 2>/dev/null | jq -r '.difficulty // empty' 2>/dev/null)
    else
        DIFFICULTY=$(bitcoin-cli getmininginfo 2>/dev/null | grep -o '"difficulty":[0-9.e+]*' | cut -d: -f2 || echo "")
    fi
    
    # Format difficulty (it's a huge number, show in scientific notation or shortened)
    if [ -n "$DIFFICULTY" ] && [ "$DIFFICULTY" != "N/A" ]; then
        # If it's a huge number, format it nicely
        if [ "$(echo "$DIFFICULTY" | wc -c)" -gt 10 ]; then
            DIFFICULTY=$(awk "BEGIN {printf \"%.2e\", $DIFFICULTY}" 2>/dev/null || echo "$DIFFICULTY")
        fi
    else
        DIFFICULTY="N/A"
    fi
    
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
<i>Note: Total hashrate from ${THREADS:-4} CPU threads combined</i>

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

