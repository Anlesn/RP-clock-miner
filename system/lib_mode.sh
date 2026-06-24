# Shared mining-mode resolver — source this file, do not execute it.
#
# Single source of truth for which way the miner gets work:
#   MINING_MODE=solo  -> local bitcoind via RPC on 127.0.0.1:8332 (full sovereignty)
#   MINING_MODE=pool  -> SoloPool.org via Stratum, no local node at all
#
# Resolution order for every value: .env override -> miner/config.json -> default.
# After sourcing, callers branch with is_solo_mode / is_pool_mode and, in pool
# mode, use POOL_URL / POOL_WORKER_ID to launch cpuminer.

# Resolve project root from THIS file's location, so it works no matter which
# directory the caller runs from. Respect an already-set PROJECT_DIR.
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$(dirname "$_LIB_DIR")}"
CONFIG_FILE="$PROJECT_DIR/miner/config.json"

# Load .env so MINING_MODE / address / pool overrides are visible. Harmless to
# re-source if the caller already loaded it.
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a
    # shellcheck disable=SC1090
    source "$PROJECT_DIR/.env"
    set +a
fi

# _cfg <key> -> string value of "key": "value" from config.json (first match)
_cfg() {
    grep -o "\"$1\":[[:space:]]*\"[^\"]*\"" "$CONFIG_FILE" 2>/dev/null \
        | head -1 | cut -d'"' -f4
}

# Mode: .env MINING_MODE wins, then config.json "mode", default solo
MINING_MODE="${MINING_MODE:-$(_cfg mode)}"
MINING_MODE="${MINING_MODE:-solo}"

# Pool connection params (only meaningful when mode=pool). .env overrides:
# POOL_PROVIDER (solopool|ckpool), POOL_REGION (eu|us), POOL_TIER (low|mid|high),
# POOL_WORKER_ID.
POOL_PROVIDER="${POOL_PROVIDER:-$(_cfg provider)}"
POOL_PROVIDER="${POOL_PROVIDER:-solopool}"
POOL_REGION="${POOL_REGION:-$(_cfg region)}"
POOL_REGION="${POOL_REGION:-eu}"
POOL_TIER="${POOL_TIER:-$(_cfg tier)}"
POOL_TIER="${POOL_TIER:-low}"
POOL_WORKER_ID="${POOL_WORKER_ID:-$(_cfg worker_id)}"
POOL_WORKER_ID="${POOL_WORKER_ID:-rpi5}"

case "$POOL_PROVIDER" in
    ckpool|ck)
        # CKPool solo (https://solo.ckpool.org). Vardiff (min 10K) — difficulty
        # auto-adapts to hashrate so even a low-power miner eventually shows on
        # the dashboard. Pick the regional sibling by POOL_REGION for lower
        # latency (less stale work). Shares are cosmetic; odds are unchanged.
        POOL_NAME="CKPool Solo"
        POOL_PORT=3333
        POOL_DIFF_LABEL="vardiff (auto, min 10K)"
        case "$POOL_REGION" in
            us|usa|US|americas) POOL_HOST="solo.ckpool.org" ;;   # Americas
            asia|sg|me)         POOL_HOST="sgsolo.ckpool.org" ;;  # Asia/Middle East
            oceania|au|nz)      POOL_HOST="ausolo.ckpool.org" ;;  # Oceania
            *)                  POOL_HOST="eusolo.ckpool.org" ;;  # Europe/Africa (default)
        esac
        ;;
    *)
        # SoloPool.org endpoints (see https://btc.solopool.org/help)
        POOL_NAME="SoloPool.org"
        case "$POOL_REGION" in
            us|usa|US) POOL_HOST="us1.solopool.org" ;;
            *)         POOL_HOST="eu3.solopool.org" ;;
        esac
        # Port selects share difficulty. RPi5 hashes ~10-50 MH/s -> low (250K).
        case "$POOL_TIER" in
            high) POOL_PORT=9005; POOL_DIFF_LABEL="10M (high)" ;;
            mid)  POOL_PORT=7005; POOL_DIFF_LABEL="1M (mid)" ;;
            *)    POOL_PORT=8005; POOL_DIFF_LABEL="250K (low)" ;;
        esac
        ;;
esac
POOL_URL="stratum+tcp://${POOL_HOST}:${POOL_PORT}"

is_pool_mode() { [ "$MINING_MODE" = "pool" ]; }
is_solo_mode() { [ "$MINING_MODE" != "pool" ]; }
