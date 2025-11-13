#!/bin/bash
# Health check and recovery script
# Ensures all components are running properly after reboot or crash

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log file for health checks
LOG_FILE="/var/log/rp-clock-miner-health.log"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to check if a process is running
is_running() {
    pgrep -f "$1" > /dev/null 2>&1
}

# Function to wait for network connectivity
wait_for_network() {
    log "Waiting for network connection..."
    local max_attempts=30
    local attempt=1
    
    while ! ping -c 1 google.com > /dev/null 2>&1; do
        if [ $attempt -ge $max_attempts ]; then
            log "ERROR: Network not available after $max_attempts attempts"
            return 1
        fi
        log "Network not ready, attempt $attempt/$max_attempts"
        sleep 2
        ((attempt++))
    done
    
    log "Network connection established"
    return 0
}

# Function to check and start Bitcoin Core
check_bitcoin_core() {
    log "Checking Bitcoin Core status..."
    
    if ! is_running "bitcoind"; then
        log "Bitcoin Core not running, starting..."
        bitcoind -daemon
        
        # Wait for Bitcoin Core to initialize
        local max_wait=60
        local waited=0
        while ! bitcoin-cli getblockchaininfo > /dev/null 2>&1; do
            if [ $waited -ge $max_wait ]; then
                log "ERROR: Bitcoin Core failed to start after ${max_wait}s"
                return 1
            fi
            sleep 2
            ((waited+=2))
        done
        
        log "Bitcoin Core started successfully"
    else
        log "Bitcoin Core already running"
    fi
    
    # Log sync status
    local blocks=$(bitcoin-cli getblockcount 2>/dev/null || echo "0")
    local headers=$(bitcoin-cli getblockchaininfo 2>/dev/null | grep -o '"headers":[[:space:]]*[0-9]*' | grep -o '[0-9]*$' || echo "0")
    log "Blockchain status: $blocks/$headers blocks"
    
    return 0
}

# Function to check display availability
check_display() {
    log "Checking display status..."
    
    # Check for HDMI display
    if tvservice -s 2>/dev/null | grep -q "HDMI"; then
        log "HDMI display detected"
        export DISPLAY_TYPE="hdmi"
        export DISPLAY=:0
        return 0
    fi
    
    # Check for I2C devices (OLED/LCD)
    if [ -e /dev/i2c-1 ]; then
        if i2cdetect -y 1 | grep -q "3c\|3d"; then
            log "I2C display detected (likely OLED)"
            export DISPLAY_TYPE="oled"
            return 0
        fi
    fi
    
    # Check for SPI display
    if [ -e /dev/spidev0.0 ]; then
        log "SPI interface available (possible display)"
        export DISPLAY_TYPE="spi"
        return 0
    fi
    
    log "No display detected, running in headless mode"
    export DISPLAY_TYPE="none"
    return 0
}

# Function to check temperature
check_temperature() {
    local temp=$(vcgencmd measure_temp | grep -o '[0-9]*\.[0-9]*' || echo "0")
    log "CPU Temperature: ${temp}°C"
    
    # Read temperature thresholds from config
    CONFIG_FILE="$PROJECT_DIR/miner/config.json"
    if [ -f "$CONFIG_FILE" ]; then
        TEMP_WARNING=$(grep -o '"temperature_warning":[[:space:]]*[0-9]*' "$CONFIG_FILE" | grep -o '[0-9]*$' || echo "70")
        TEMP_CRITICAL=$(grep -o '"temperature_critical":[[:space:]]*[0-9]*' "$CONFIG_FILE" | grep -o '[0-9]*$' || echo "80")
    else
        TEMP_WARNING=70
        TEMP_CRITICAL=80
    fi
    
    # Check if temperature is critical
    if (( $(echo "$temp > $TEMP_CRITICAL" | bc -l) )); then
        log "WARNING: Temperature critical! ${temp}°C (threshold: ${TEMP_CRITICAL}°C)"
        # Could implement throttling here
    elif (( $(echo "$temp > $TEMP_WARNING" | bc -l) )); then
        log "WARNING: Temperature high! ${temp}°C (threshold: ${TEMP_WARNING}°C)"
    fi
}

# Function to ensure swap is enabled
check_swap() {
    if ! swapon -s | grep -q "/swapfile"; then
        log "Swap not active, enabling..."
        if [ -f /swapfile ]; then
            sudo swapon /swapfile
            log "Swap enabled"
        else
            log "WARNING: No swap file found"
        fi
    else
        log "Swap already active"
    fi
}

# Function to clean up stale processes
cleanup_stale_processes() {
    log "Checking for stale processes..."
    
    # Kill any zombie cpuminer processes
    if pgrep -f "cpuminer.*defunct" > /dev/null; then
        log "Cleaning up defunct cpuminer processes"
        pkill -9 -f "cpuminer.*defunct"
    fi
    
    # Remove stale PID files
    if [ -f /var/run/rp-clock-miner.pid ]; then
        local pid=$(cat /var/run/rp-clock-miner.pid)
        if ! kill -0 "$pid" 2>/dev/null; then
            log "Removing stale PID file"
            rm -f /var/run/rp-clock-miner.pid
        fi
    fi
}

# Main health check function
main() {
    log "============================================"
    log "Starting RP-Clock-Miner Health Check"
    log "============================================"
    
    # 0. Check for power failure recovery
    if [ -f "$(dirname "$0")/power_recovery.sh" ]; then
        bash "$(dirname "$0")/power_recovery.sh"
    fi
    
    # 1. Wait for network
    if ! wait_for_network; then
        log "ERROR: Cannot proceed without network"
        exit 1
    fi
    
    # 2. Check and enable swap
    check_swap
    
    # 3. Clean up any stale processes
    cleanup_stale_processes
    
    # 4. Check temperature
    check_temperature
    
    # 5. Check and start Bitcoin Core
    if ! check_bitcoin_core; then
        log "ERROR: Bitcoin Core health check failed"
        exit 1
    fi
    
    # 6. Check display
    check_display
    
    # 7. Create status file for the main script
    cat > /tmp/rp-miner-status << EOF
HEALTH_CHECK_TIME=$(date '+%Y-%m-%d %H:%M:%S')
NETWORK_STATUS=OK
BITCOIN_CORE_STATUS=OK
DISPLAY_TYPE=$DISPLAY_TYPE
TEMPERATURE=$(vcgencmd measure_temp | grep -o '[0-9]*\.[0-9]*')
EOF
    
    log "Health check completed successfully"
    log "============================================"
    
    return 0
}

# Run main function
main "$@"
