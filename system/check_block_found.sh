#!/bin/bash
# Monitor for found blocks and send Telegram notification
# Run by monitor.sh every 5 minutes

# Ensure PATH
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

# Get project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

# Exit if Telegram not configured
if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    exit 0
fi

# Resolve mining mode. This detector scans the local node's debug.log, which
# only exists in solo mode. In pool mode SoloPool.org detects the found block
# server-side; the win shows up as the address balance in telegram_stats.
source "$SCRIPT_DIR/lib_mode.sh"
if is_pool_mode; then
    exit 0
fi

# Track file to remember last checked position
STATE_FILE="/tmp/rp-miner-block-check-state"
BITCOIN_LOG="$HOME/.bitcoin/debug.log"

# Initialize state file if doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo "0" > "$STATE_FILE"
fi

LAST_LINE=$(cat "$STATE_FILE")

# Check Bitcoin Core logs for successful block submission
# Look for "AddToWallet" with coinbase transaction (means we mined it!)
NEW_BLOCKS=$(tail -n +$LAST_LINE "$BITCOIN_LOG" 2>/dev/null | grep -c "AddToWallet.*coinbase")

if [ "$NEW_BLOCKS" -gt 0 ]; then
    # WE FOUND A BLOCK! 🎉
    BLOCK_HEIGHT=$(bitcoin-cli getblockcount 2>/dev/null || echo "Unknown")
    BLOCK_HASH=$(bitcoin-cli getbestblockhash 2>/dev/null || echo "Unknown")
    REWARD="3.125"  # Current block reward (after 2024 halving)
    
    # Get mining address balance
    if [ -n "$BITCOIN_MINING_ADDRESS" ]; then
        # Try to get balance (this only works if address is in wallet)
        BALANCE=$(bitcoin-cli getreceivedbyaddress "$BITCOIN_MINING_ADDRESS" 0 2>/dev/null || echo "Check wallet")
    else
        BALANCE="N/A"
    fi
    
    MESSAGE="🎉🎉🎉 <b>BLOCK FOUND!!!</b> 🎉🎉🎉

💎 <b>YOU MINED A BITCOIN BLOCK!</b>

🎰 Block Height: ${BLOCK_HEIGHT}
🔗 Block Hash: <code>${BLOCK_HASH:0:16}...</code>
💰 Reward: ${REWARD} BTC (~\$$(echo "$REWARD * 95000" | bc) USD)

📍 Mining Address:
<code>${BITCOIN_MINING_ADDRESS}</code>

📊 Your Balance: ${BALANCE} BTC

⏰ Time: $(date '+%Y-%m-%d %H:%M:%S')

<b>CONGRATULATIONS! 🚀🚀🚀</b>
<i>You beat astronomical odds!</i>"
    
    # Send notification
    if [ -f "$SCRIPT_DIR/telegram_notify.sh" ]; then
        bash "$SCRIPT_DIR/telegram_notify.sh" "$MESSAGE"
    fi
    
    # Log the event
    logger -t rp-clock-miner-BLOCK "🎉 BLOCK FOUND! Height: $BLOCK_HEIGHT, Hash: $BLOCK_HASH"
fi

# Update state file
wc -l < "$BITCOIN_LOG" > "$STATE_FILE"

