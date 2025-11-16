# RP-clock-miner 🎰⏰

A decorative Bitcoin solo mining setup for Raspberry Pi 5 that doubles as a desktop clock display.

*Note:* display functionality is not implemented yet, ignore it, so this project only works as RPi5-based solo-miner which you can put in pretty case and keep on your desktop as interior accessory.

<p align="center">
  <img src="https://img.shields.io/badge/Raspberry%20Pi-5-C51A4A?style=for-the-badge&logo=raspberry-pi" />
  <img src="https://img.shields.io/badge/Bitcoin-Solo%20Mining-F7931A?style=for-the-badge&logo=bitcoin" />
  <img src="https://img.shields.io/badge/Type-Decorative-00D4FF?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Security-Enhanced-4CAF50?style=for-the-badge&logo=shield" />
</p>

## 🎯 What is This Project?

**RP-clock-miner** is a DIY project that transforms your Raspberry Pi 5 into a decorative Bitcoin solo miner that doubles as a smart desktop clock. It's designed to be a beautiful, functional desk accessory that actually mines Bitcoin - albeit with lottery-like odds.

### What Makes It Special?

- **True Solo Mining**: No pools - you're mining directly on the Bitcoin network
- **Minimal Resources**: Uses pruned node (~5GB) instead of full node (500+ GB)
- **Fully Autonomous**: Set it and forget it - survives reboots and power failures
- **Professional Code**: Production-ready security and error handling
- **Beautiful Display**: Customizable themes for your desk aesthetic

## 📸 Features

### Core Functionality
- **True Solo Mining**: Direct block mining without pools
- **Pruned Node**: Only ~5GB storage needed (vs 500+ GB full node)
- **Auto-Recovery**: Survives power failures and crashes
- **24/7 Operation**: Fully autonomous after initial setup

### Display Information (Coming Soon)
Display functionality is planned but not yet implemented. Future versions will show:
- 🕐 Current time and date
- ⚡ Real-time hashrate
- 💰 Live Bitcoin price
- 📊 Network difficulty
- 🌡️ CPU temperature
- 📈 Mining statistics
- 🎯 Block information

### Security Features
- 🔑 Secure wallet generation
- 🔒 Environment-based secrets
- 💾 Encrypted backup tools
- 🛡️ Hardware wallet support

## 🛠️ Requirements

### Hardware
- **Raspberry Pi 5** (4GB or 8GB RAM)
- **MicroSD Card** (64GB minimum, Class A2 recommended)
- **Power Supply** (5V/5A official RPi5 PSU)
- **Cooling** (Active cooling recommended for 24/7 operation)
- **Display** (Optional)
  - HDMI monitor, or
  - I2C OLED/LCD display, or
  - SPI e-ink display

### Software
- Raspberry Pi OS (64-bit)
- Python 3.9+
- Git

### External Dependencies
- **Bitcoin Core** (latest version) - Full node software (auto-downloaded during setup)
- **cpuminer-opt** - CPU mining software ([JayDDee/cpuminer-opt](https://github.com/JayDDee/cpuminer-opt))
- **Python Libraries** (via pip):
  - `requests` - API calls for BTC price and mining stats
  - `psutil` - System resource monitoring
  - `matplotlib` - Chart generation for statistics
  - `rich` - Terminal UI for testing without display
  - Optional display drivers (pygame, luma, waveshare-epd) - based on your display type

### System Utilities (installed automatically):
- `build-essential` - C++ compiler for cpuminer
- `automake`, `autoconf` - Build tools
- `libssl-dev`, `libcurl4-openssl-dev` - Crypto libraries
- `libjansson-dev` - JSON parsing
- `libgmp-dev` - Multi-precision arithmetic
- `zlib1g-dev` - Compression
- `libnuma-dev` - NUMA support
- `git`, `curl`, `wget` - Download tools
- `bc`, `jq` - Command-line calculators

## 🚀 Quick Start

### 1. Initial Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/RP-clock-miner.git
cd RP-clock-miner

# Make scripts executable
chmod +x secrets/*.sh
chmod +x system/*.sh node/*.sh miner/*.sh
```

### 2. Configure Security

```bash
# Generate secure credentials
bash secrets/generate_secrets.sh
```

Choose one of three options:
1. **Pre-defined credentials** (simplest for testing)
2. **Generate secure password** (recommended)
3. **Enter custom credentials** (for your own values)

```bash
# Apply configuration
bash secrets/set_secrets.sh
```

### 3. Install Components

```bash
# Install Bitcoin Core and system dependencies
bash node/setup_node.sh

# Set up automatic startup and monitoring
bash system/install_autostart.sh
```

This will:
- Install Bitcoin Core with pruned mode
- Set up swap file (2-4GB based on RAM)
- Install all dependencies
- Configure systemd service and cron monitoring

### 4. Start Mining

#### Option A: Using System Service (Recommended)
```bash
# Start the complete system service
sudo systemctl start rp-clock-miner

# Check status
sudo systemctl status rp-clock-miner

# View logs
journalctl -u rp-clock-miner -f
```

#### Option B: Manual Testing
```bash
# Start Bitcoin Core manually
bitcoind -daemon

# Wait for initial sync (check progress)
watch -n 10 'bitcoin-cli getblockchaininfo | grep -E "blocks|headers|progress"'

# Test the miner directly
cd miner
./run_miner.sh
```

## 🔄 Daily Usage & Management

### Starting/Stopping
```bash
# Start mining
sudo systemctl start rp-clock-miner

# Stop mining
sudo systemctl stop rp-clock-miner

# Restart (after config changes)
sudo systemctl restart rp-clock-miner

# Check if running
sudo systemctl status rp-clock-miner
```

### Monitoring
```bash
# Live logs
journalctl -u rp-clock-miner -f

# Today's logs
journalctl -u rp-clock-miner --since today

# Check sync progress
bitcoin-cli getblockchaininfo | jq '.blocks, .headers'

# Mining statistics (if cpuminer API is running)
curl -s http://127.0.0.1:4048/summary | jq

# Send Telegram stats manually
bash system/telegram_stats.sh

# System health
htop  # CPU usage and temperature
```

### Troubleshooting
```bash
# If service fails to start
sudo journalctl -u rp-clock-miner -n 50

# Check Bitcoin Core
bitcoin-cli getnetworkinfo

# Manual health check
bash system/health_check.sh

# Force recovery after power failure
bash system/power_recovery.sh
```

## 📁 Project Structure

```
RP-clock-miner/
├── node/                 # Bitcoin Core configuration
│   ├── bitcoin.conf      # Pruned node settings
│   └── setup_node.sh     # Installation script
├── miner/               # CPU mining software
│   ├── config.json      # Mining parameters
│   └── run_miner.sh     # Miner startup script
├── display/             # Display dashboard (NOT IMPLEMENTED YET)
│   ├── display.py       # Main display script (placeholder)
│   ├── config.json      # Display configuration (placeholder)
│   └── requirements.txt # Python dependencies (placeholder)
├── secrets/             # Security tools
│   ├── generate_secrets.sh    # Credential generator
│   ├── set_secrets.sh        # Apply configuration
│   └── README.md            # Security guide
└── system/              # System integration
    ├── autostart.service     # Systemd service
    ├── health_check.sh       # Health monitoring
    ├── power_recovery.sh     # Power failure recovery
    ├── monitor.sh            # Cron-based monitoring
    ├── start.sh              # Main startup orchestrator
    ├── install_autostart.sh  # Auto-start installer
    ├── telegram_notify.sh    # Telegram message sender
    └── telegram_stats.sh     # Telegram statistics reporter
```

## 🔗 Script Dependencies & Flow

### Startup Flow
1. **System Boot** → `systemd` starts `rp-clock-miner.service`
2. **Service Start** → `autostart.service` executes:
   - `health_check.sh` (pre-start health check)
   - `start.sh` (main orchestrator)
3. **start.sh** orchestrates:
   - Loads `.env` variables
   - Starts Bitcoin Core daemon
   - Detects display type (for future use)
   - Launches `display/display.py` (NOT IMPLEMENTED - will be skipped)
   - Starts `miner/run_miner.sh`

### Health & Recovery Flow
- **Every 5 minutes**: `cron` runs `monitor.sh`
  - Checks service status → restarts if needed
  - Monitors temperature → reads from `config.json`
  - Checks disk space → alerts if >90% full
- **On power failure**: `power_recovery.sh` (called by `health_check.sh`)
  - Detects unclean shutdown
  - Cleans lock files
  - Repairs Bitcoin database if needed

### Mining Flow
1. `run_miner.sh` starts and:
   - Loads `.env` for RPC credentials
   - Reads `miner/config.json` for settings
   - Checks Bitcoin Core sync status
   - Compiles/updates `cpuminer-opt` if needed
   - Starts CPU mining process

### Configuration Flow
- `generate_secrets.sh` → Creates `.env` file
- `set_secrets.sh` → Applies `.env` to `bitcoin.conf` and `config.json`

## ⚙️ Configuration

### Environment Variables (.env)
```bash
# Critical security data only
BITCOIN_RPC_USER=your_username
BITCOIN_RPC_PASSWORD=your_secure_password
BITCOIN_MINING_ADDRESS=your_bitcoin_address

# Optional: Telegram notifications
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here
```

### Mining Settings (miner/config.json)
```json
{
  "mining": {
    "threads": 4,        // CPU threads (2-4 recommended)
    "priority": 10       // Process priority
  },
  "monitoring": {
    "temperature_critical": 80  // Critical temp in °C
  }
}
```

### Display Settings (display/config.json) - NOT IMPLEMENTED YET
Display functionality is planned for future versions. Configuration file exists but is not currently used.

### Telegram Notifications (Optional)
Get real-time updates on your phone while display is not yet implemented!

**Setup:**
1. Create Telegram bot via [@BotFather](https://t.me/botfather)
   - Send `/newbot`
   - Choose name and username
   - Copy the **bot token**

2. Get your Chat ID:
   - Send any message to your bot
   - Visit: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Find `"chat":{"id":123456789}` - this is your **chat ID**

3. Add to `.env`:
   ```bash
   TELEGRAM_BOT_TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
   TELEGRAM_CHAT_ID=123456789
   ```

4. Test:
   ```bash
   bash system/telegram_notify.sh "Test message!"
   ```

**What you'll receive:**
- 🎉🎉🎉 **INSTANT notification when you find a block!** (checked every 5 min)
- 🎉 Notification when blockchain sync completes
- 📊 Mining statistics every 30 minutes (configurable in `miner/config.json`)
  - Mining status, hashrate, shares
  - Blockchain sync progress
  - Bitcoin price and your wallet balance
  - Network difficulty
  - System resources (temperature, memory, disk)

## 📊 Performance & Probability

### Expected Performance
- **Hashrate**: ~10-50 MH/s on RPi5
- **Power**: ~15-25W under load
- **Temperature**: 60-70°C with cooling

### Mining Probability
- **Per Day**: ~0.0000000001%
- **Per Year**: ~0.0000365%
- **Per Century**: ~0.00365%

*Current block reward: 3.125 BTC (after 2024 halving)*

## 🔧 Maintenance

### Monitoring Commands
```bash
# View real-time logs
journalctl -u rp-clock-miner -f

# Check temperature
vcgencmd measure_temp

# Bitcoin Core status
bitcoin-cli getblockchaininfo

# Mining statistics
curl http://127.0.0.1:4048/summary
```

## 🛡️ Security Best Practices

1. **Use Hardware Wallet Address**: Mining rewards go directly to your external address
2. **Backup External Wallet**: This project doesn't store wallet keys - backup your external wallet properly
3. **Secure .env File**: Never commit to git (contains RPC credentials)
4. **Update System**: Keep software up to date
5. **Monitor Temperature**: Prevent thermal damage
6. **RPC Credentials**: Can be regenerated anytime if compromised

## ⚠️ Important Notes

### Initial Sync Warning
- **First sync takes SEVERAL DAYS and ~550GB download**
- Even with pruning enabled, Bitcoin Core must download and verify ALL historical blocks
- Only after full sync will it prune to 5GB storage
- **Mining cannot start until blockchain is fully synced**
- Ensure stable internet connection during initial sync

### General Notes
- This is a **decorative/educational project**, not a profitable mining operation
- Monitor **temperature** to prevent damage
- Create **backups** before any changes

## 🤝 Contributing

Pull requests welcome for:
- New display themes
- Performance optimizations
- Additional hardware support
- Security improvements
- Documentation updates

## 📜 License

MIT License - Use at your own risk!

## 🙏 Acknowledgments

- Satoshi Nakamoto for Bitcoin
- Raspberry Pi Foundation
- cpuminer-opt developers
- The Bitcoin community

---

**Remember**: This is art, not business. If you do find a block, you'll have the coolest story in crypto! 🚀

*P.S. The probability is tiny, but non-zero. Someone will find the next block - why not you?*

*P.S.S. This repository is vibe-coded. Vibe-code is a great tool which helps you to save some time and even learn new things, but always keep in mind what you have to check everything what LLM did on your request*