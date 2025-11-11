# Secrets Management

This directory contains scripts for managing sensitive configuration data.

## Scripts

### `generate_secrets.sh`
Creates `.env` file with all necessary secrets:
- Bitcoin RPC credentials
- Bitcoin address for rewards

```bash
bash secrets/generate_secrets.sh
```

Options:
1. Pre-defined credentials (for testing)
2. Generate secure password (recommended)
3. Enter custom credentials

### `set_secrets.sh`
Applies secrets from `.env` to system configuration:
- Updates Bitcoin Core settings
- Sets secure file permissions

```bash
bash secrets/set_secrets.sh
```

### `backup_secrets.sh`
Creates encrypted backup of your secrets and configuration.

```bash
bash secrets/backup_secrets.sh
```

## Quick Start

1. Generate secrets: `bash secrets/generate_secrets.sh`
2. Apply configuration: `bash secrets/set_secrets.sh`
3. Create backup: `bash secrets/backup_secrets.sh`

## Security Notes

- **Never commit `.env` to git**
- **Use hardware wallet address when possible**
- **Store backups securely**