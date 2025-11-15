#!/bin/bash
# Telegram notification helper
# Sends messages to configured Telegram bot

# Get project directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load Telegram credentials from .env
if [ -f "$PROJECT_DIR/.env" ]; then
    source "$PROJECT_DIR/.env"
fi

# Function to send Telegram message
send_telegram() {
    local message="$1"
    
    # Check if Telegram is configured
    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        echo "[!] Telegram not configured. Set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in .env"
        return 1
    fi
    
    # Send message via Telegram Bot API
    local response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true")
    
    # Check if successful
    if echo "$response" | grep -q '"ok":true'; then
        echo "[✓] Telegram message sent"
        return 0
    else
        echo "[!] Failed to send Telegram message"
        echo "$response" | grep -o '"description":"[^"]*"' | cut -d'"' -f4
        return 1
    fi
}

# If called directly with a message argument
if [ $# -gt 0 ]; then
    MESSAGE="$*"
    send_telegram "$MESSAGE"
else
    echo "Usage: $0 <message>"
    echo "Example: $0 'Bitcoin sync completed!'"
    exit 1
fi

