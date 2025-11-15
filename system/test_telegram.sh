#!/bin/bash
# Quick Telegram test script - no .env needed
# Usage: ./test_telegram.sh <bot_token> <chat_id>

if [ $# -lt 2 ]; then
    echo "Usage: $0 <BOT_TOKEN> <CHAT_ID>"
    echo ""
    echo "Example:"
    echo "  $0 1234567890:ABCdef... 123456789"
    echo ""
    echo "Get bot token from @BotFather"
    echo "Get chat ID from: https://api.telegram.org/bot<TOKEN>/getUpdates"
    exit 1
fi

BOT_TOKEN="$1"
CHAT_ID="$2"

echo "Testing Telegram connection..."
echo "Bot Token: ${BOT_TOKEN:0:10}..."
echo "Chat ID: $CHAT_ID"
echo ""

# Test 1: Simple text message
echo "[1/3] Sending test message..."
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=✅ Test message from RPi5 miner!" \
    -d "parse_mode=HTML")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ Simple message sent successfully!"
else
    echo "❌ Failed to send message!"
    echo "$RESPONSE" | grep -o '"description":"[^"]*"' | cut -d'"' -f4
    exit 1
fi

sleep 1

# Test 2: Formatted message with stats
echo "[2/3] Sending formatted stats..."
MESSAGE="<b>🎰 RP Solo Miner Test</b>

<b>⛏️ Mining Status:</b>
Status: ✅ Testing
Hashrate: 42.0 KH/s

<b>🖥️ System:</b>
Temperature: 50°C
Memory: OK

<i>Time: $(date '+%Y-%m-%d %H:%M:%S')</i>"

RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=${MESSAGE}" \
    -d "parse_mode=HTML" \
    -d "disable_web_page_preview=true")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ Formatted message sent successfully!"
else
    echo "❌ Failed to send formatted message!"
    echo "$RESPONSE" | grep -o '"description":"[^"]*"' | cut -d'"' -f4
    exit 1
fi

sleep 1

# Test 3: Emoji test
echo "[3/3] Sending emoji test..."
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=🎉 Emoji test: ✅ ❌ ⚠️ 🚀 💰 ⛏️ 🌡️ 📊" \
    -d "parse_mode=HTML")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo "✅ Emoji message sent successfully!"
else
    echo "❌ Failed to send emoji message!"
    exit 1
fi

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ All tests passed!                  ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "Your Telegram bot is working correctly!"
echo "Now add these credentials to your .env file:"
echo ""
echo "TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
echo "TELEGRAM_CHAT_ID=$CHAT_ID"

