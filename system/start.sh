#!/bin/bash
# Robust startup script with health checks and recovery
# Handles power failures, crashes, and network issues gracefully

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Log file
LOG_FILE="/var/log/rp-clock-miner.log"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Trap to handle cleanup on exit
cleanup() {
    log "Shutdown signal received, cleaning up..."
    pkill -f "display.py" || true
    pkill -f "cpuminer" || true
    log "Cleanup completed"
}
trap cleanup EXIT SIGTERM SIGINT

log "=========================================="
log "Starting RP-Clock-Miner Service"
log "=========================================="

# 1. Run health check first
log "Running system health check..."
if ! bash "$SCRIPT_DIR/health_check.sh"; then
    log "ERROR: Health check failed!"
    exit 1
fi

# 2. Load environment variables
if [ -f "$PROJECT_DIR/.env" ]; then
    log "Loading environment variables..."
    set -a  # Export all variables
    source "$PROJECT_DIR/.env"
    set +a
else
    log "ERROR: .env file not found!"
    exit 1
fi

# 3. Check if Bitcoin Core is already running (from health check)
if ! pgrep -f "bitcoind" > /dev/null; then
    log "Starting Bitcoin Core..."
    bitcoind -daemon
    
    # More robust wait with timeout
    timeout=120
    elapsed=0
    while ! bitcoin-cli getblockchaininfo > /dev/null 2>&1; do
        if [ $elapsed -ge $timeout ]; then
            log "ERROR: Bitcoin Core failed to start within ${timeout}s"
            exit 1
        fi
        sleep 2
        ((elapsed+=2))
        if [ $((elapsed % 10)) -eq 0 ]; then
            log "Waiting for Bitcoin Core... ${elapsed}s"
        fi
    done
fi

log "Bitcoin Core is ready"

# 4. Load display configuration
source /tmp/rp-miner-status 2>/dev/null || true

# 5. Start display if available
if [ "$DISPLAY_TYPE" != "none" ] && [ -f "$PROJECT_DIR/display/display.py" ]; then
    log "Starting display dashboard (type: $DISPLAY_TYPE)..."
    
    # Kill any existing display process
    pkill -f "display.py" || true
    sleep 1
    
    # Start display with appropriate environment
    case "$DISPLAY_TYPE" in
        "hdmi")
            export DISPLAY=:0
            export SDL_VIDEODRIVER=x11
            ;;
        "oled"|"lcd")
            export I2C_BUS=1
            ;;
        "spi")
            export SPI_DEVICE=/dev/spidev0.0
            ;;
    esac
    
    # Run display in background with output redirection
    cd "$PROJECT_DIR/display"
    python3 display.py >> "$LOG_FILE" 2>&1 &
    DISPLAY_PID=$!
    
    # Verify display started
    sleep 2
    if kill -0 $DISPLAY_PID 2>/dev/null; then
        log "Display started successfully (PID: $DISPLAY_PID)"
    else
        log "WARNING: Display failed to start, continuing without display"
    fi
else
    log "Running in headless mode (no display)"
fi

# 6. Final pre-flight checks
log "Performing final checks..."

# Check temperature
temp=$(vcgencmd measure_temp | grep -o '[0-9]*\.[0-9]*' || echo "0")
log "Current temperature: ${temp}°C"

# Check available memory
available_mem=$(free -m | awk 'NR==2{printf "%.1f", $7/1024}')
log "Available memory: ${available_mem}GB"

# 7. Start the miner
log "Starting CPU miner..."
cd "$PROJECT_DIR/miner"

# Create a PID file
echo $$ > /var/run/rp-clock-miner.pid

# Run miner in foreground so systemd can track it
# The miner script will handle its own error recovery
exec ./run_miner.sh