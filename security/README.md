# Security Scripts

This directory contains scripts for secure credential management.

## Scripts

### `create_credentials.sh`
Creates `.env` file with your Bitcoin address and RPC credentials.

```bash
bash security/create_credentials.sh
```

Options:
1. Use pre-defined credentials (for testing)
2. Generate secure password (recommended)
3. Enter custom credentials

### `set_credentials.sh`
Applies credentials from `.env` to Bitcoin Core configuration.

```bash
bash security/set_credentials.sh
```

### `backup_wallet.sh`
Creates backup of your configuration and credentials.

```bash
bash security/backup_wallet.sh
```

## Quick Start

1. Run `create_credentials.sh` to create `.env`
2. Run `set_credentials.sh` to apply `.env` to settings
3. Run `backup_wallet.sh` periodically for backups

## Important

- **Never commit `.env` to git**
- **Use hardware wallet address if possible**
- **Keep backups in multiple places**