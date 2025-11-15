#!/bin/bash
# Bitcoin solo mining startup script for Raspberry Pi 5
# Handles wallet creation, miner compilation, and monitoring

# Exit on any error to prevent running with incorrect configuration
set -e

# Change to script directory (where config.json should be)
cd "$(dirname "$0")"

# ANSI color codes for pretty terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Display startup banner
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Raspberry Pi Solo Bitcoin Miner       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo

# Load environment variables if .env exists
if [ -f ../.env ]; then
    echo -e "${BLUE}[*] Loading environment variables...${NC}"
    source ../.env
fi

# Check if configuration file exists
if [ ! -f ./config.json ]; then
    echo -e "${RED}[!] config.json not found!${NC}"
    exit 1
fi

# Parse configuration values from JSON
# grep -o: Only output matching parts
# cut -d'"' -f4: Extract value between quotes
RPC_USER=$(grep -o '"user":[[:space:]]*"[^"]*"' config.json | cut -d'"' -f4)
RPC_PASS=$(grep -o '"password":[[:space:]]*"[^"]*"' config.json | cut -d'"' -f4)
THREADS=$(grep -o '"threads":[[:space:]]*[0-9]*' config.json | grep -o '[0-9]*$')
PRIORITY=$(grep -o '"priority":[[:space:]]*[0-9]*' config.json | grep -o '[0-9]*$')
COINBASE_ADDR=$(grep -o '"address":[[:space:]]*"[^"]*"' config.json | cut -d'"' -f4)
COINBASE_MSG=$(grep -o '"message":[[:space:]]*"[^"]*"' config.json | cut -d'"' -f4 || echo "RPi5 Solo Miner")

# Override with environment variables if they exist (only security-critical data)
RPC_USER=${BITCOIN_RPC_USER:-$RPC_USER}
RPC_PASS=${BITCOIN_RPC_PASSWORD:-$RPC_PASS}
COINBASE_ADDR=${BITCOIN_MINING_ADDRESS:-$COINBASE_ADDR}
# Note: THREADS and other settings come from config.json only

# Check if Bitcoin Core is running
echo -e "${YELLOW}[*] Checking Bitcoin Core status...${NC}"
if bitcoin-cli getblockchaininfo >/dev/null 2>&1; then
    # Get current blockchain sync status
    BLOCKS=$(bitcoin-cli getblockcount)
    HEADERS=$(bitcoin-cli getblockchaininfo | grep -o '"headers":[[:space:]]*[0-9]*' | grep -o '[0-9]*$')
    PROGRESS=$(bitcoin-cli getblockchaininfo | grep -o '"verificationprogress":[[:space:]]*[0-9.]*' | grep -o '[0-9.]*$')
    
    # Calculate sync percentage (multiply by 100 and remove decimals)
    # Check if bc is available, fallback to awk if not
    if command -v bc >/dev/null 2>&1; then
        PROGRESS_PCT=$(echo "$PROGRESS * 100" | bc | cut -d'.' -f1)
    else
        PROGRESS_PCT=$(awk "BEGIN {printf \"%.0f\", $PROGRESS * 100}")
    fi
    
    echo -e "${GREEN}[✓] Bitcoin Core is running${NC}"
    echo -e "    Blocks: $BLOCKS / $HEADERS (${PROGRESS_PCT}% synced)"
    
    # Check if fully synced
    if [ "$BLOCKS" -lt "$HEADERS" ]; then
        echo -e "${YELLOW}[!] Bitcoin Core is still syncing blockchain...${NC}"
        
        # Estimate remaining time (very rough)
        BLOCKS_LEFT=$((HEADERS - BLOCKS))
        
        # Check if this is catch-up sync (small number of blocks) or initial sync
        if [ $BLOCKS_LEFT -lt 1000 ]; then
            echo -e "${YELLOW}    Catching up after being offline (${BLOCKS_LEFT} blocks behind)${NC}"
            echo -e "${YELLOW}    This should only take a few minutes.${NC}"
        else
            echo -e "${YELLOW}    This is normal for first run. Full sync can take several days.${NC}"
            echo -e "${YELLOW}    Progress: ${PROGRESS_PCT}% (Block $BLOCKS of $HEADERS)${NC}"
            echo -e "${CYAN}    Blocks remaining: $BLOCKS_LEFT${NC}"
            echo ""
            echo -e "${CYAN}[i] Pruned node still needs to download and verify ALL blocks${NC}"
            echo -e "${CYAN}    but will only keep last 5GB after verification.${NC}"
            echo -e "${CYAN}    Initial sync requires more than 500GB to be downloaded and verified over several days.${NC}"
        fi
        
        echo ""
        echo -e "${RED}[!] Cannot mine until fully synced. Exiting...${NC}"
        exit 1
    fi
else
    echo -e "${RED}[!] Bitcoin Core is not running!${NC}"
    echo -e "    Start it with: bitcoind -daemon"
    exit 1
fi

# Check mining address configuration
echo -e "${YELLOW}[*] Checking mining address...${NC}"
if [ "$COINBASE_ADDR" = "YOUR_BITCOIN_ADDRESS_HERE" ] || [ "$COINBASE_ADDR" = "PLACEHOLDER" ]; then
    echo -e "${RED}[!] Mining address not configured!${NC}"
    echo "Please run: bash secrets/generate_secrets.sh"
    echo "Then run: bash secrets/set_secrets.sh"
    exit 1
else
    echo -e "${GREEN}[✓] Using mining address: $COINBASE_ADDR${NC}"
fi

# Build or update cpuminer-opt
CPUMINER_REPO="/tmp/cpuminer-opt"
UPDATE_CHECK_FILE="./cpuminer_last_update"
DAYS_BETWEEN_CHECKS=7

# Function to build cpuminer
build_cpuminer() {
    echo -e "${YELLOW}[*] Building cpuminer-opt...${NC}"
    
    # Configure build
    cd "$CPUMINER_REPO"
    ./autogen.sh
    
    # Compile with maximum optimization for current CPU
    # -O3: Maximum optimization
    # -march=native: Optimize for this specific CPU
    CFLAGS="-O3 -march=native" ./configure --with-curl
    
    # Build using all available CPU cores
    make -j$(nproc)
    
    # Copy binary to miner directory
    cp cpuminer "$OLDPWD/"
    cd "$OLDPWD"
    
    # Update last check timestamp
    date +%s > "$UPDATE_CHECK_FILE"
    
    echo -e "${GREEN}[✓] cpuminer built successfully${NC}"
}

# Check if we need to build or update
NEED_BUILD=0
if [ ! -f ./cpuminer ]; then
    echo -e "${YELLOW}[*] cpuminer not found, need to build...${NC}"
    NEED_BUILD=1
else
    # Check if it's time to check for updates
    if [ -f "$UPDATE_CHECK_FILE" ]; then
        LAST_CHECK=$(cat "$UPDATE_CHECK_FILE")
        CURRENT_TIME=$(date +%s)
        DAYS_PASSED=$(( (CURRENT_TIME - LAST_CHECK) / 86400 ))
        
        if [ $DAYS_PASSED -ge $DAYS_BETWEEN_CHECKS ]; then
            echo -e "${YELLOW}[*] Checking for cpuminer updates...${NC}"
            
            # Clone or update repo
            if [ -d "$CPUMINER_REPO" ]; then
                cd "$CPUMINER_REPO"
                git fetch origin
                LOCAL_HASH=$(git rev-parse HEAD)
                REMOTE_HASH=$(git rev-parse origin/master)
                
                if [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
                    echo -e "${YELLOW}[*] New version available!${NC}"
                    git pull
                    NEED_BUILD=1
                else
                    echo -e "${GREEN}[✓] cpuminer is up to date${NC}"
                    date +%s > "$OLDPWD/$UPDATE_CHECK_FILE"
                fi
                cd "$OLDPWD"
            else
                NEED_BUILD=1
            fi
        fi
    else
        # First run, create update check file
        date +%s > "$UPDATE_CHECK_FILE"
    fi
fi

# Build if needed
if [ $NEED_BUILD -eq 1 ]; then
    # Clone or update repository
    if [ ! -d "$CPUMINER_REPO" ]; then
        git clone https://github.com/JayDDee/cpuminer-opt.git "$CPUMINER_REPO"
    fi
    
    build_cpuminer
    
    # Clean up build directory
    rm -rf "$CPUMINER_REPO"
fi

# Display system information
echo
echo -e "${BLUE}System Info:${NC}"
echo "  CPU: $(lscpu | grep "Model name" | cut -d':' -f2 | xargs)"
echo "  Threads: $THREADS"
echo "  Memory: $(free -h | awk '/^Mem:/ {print $2}')"
# vcgencmd is RPi specific command for temperature
echo "  Temperature: $(vcgencmd measure_temp 2>/dev/null | cut -d'=' -f2 || echo "N/A")"

# Show network mining difficulty
echo
echo -e "${BLUE}Network Info:${NC}"
DIFFICULTY=$(bitcoin-cli getmininginfo | grep -o '"difficulty":[[:space:]]*[0-9.e+]*' | grep -o '[0-9.e+]*$')
echo "  Difficulty: $DIFFICULTY"
echo "  Your approximate hashrate: ~10-50 MH/s"
echo "  Probability of finding a block: ~0.0000000001% per day 🎲"
echo

# Start mining
echo -e "${GREEN}[*] Starting solo mining...${NC}"
echo -e "${GREEN}[*] May the odds be ever in your favor! 🍀${NC}"
echo "─────────────────────────────────────────────"

# Launch cpuminer with solo mining configuration
# -a sha256d: Bitcoin's double SHA256 algorithm
# -o: RPC endpoint of local Bitcoin Core
# -u/-p: RPC credentials from config
# --coinbase-addr: Where block rewards go
# --coinbase-sig: Message in coinbase transaction
# -t: Number of mining threads
# --cpu-priority: Nice level (10 = lower priority)
# --api-bind: API for monitoring on port 4048
./cpuminer \
    -a sha256d \
    -o http://127.0.0.1:8332 \
    -u $RPC_USER \
    -p $RPC_PASS \
    --coinbase-addr=$COINBASE_ADDR \
    --coinbase-sig="$COINBASE_MSG" \
    -t $THREADS \
    --cpu-priority ${PRIORITY:-10} \
    --api-bind 127.0.0.1:4048