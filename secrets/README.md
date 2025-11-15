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

## Quick Start

1. Generate secrets: `bash secrets/generate_secrets.sh`
2. Apply configuration: `bash secrets/set_secrets.sh`

## Security Notes

- **Never commit `.env` to git**
- **Use public wallet address for mining rewards**
- **RPC credentials can be regenerated anytime via generate_secrets.sh**