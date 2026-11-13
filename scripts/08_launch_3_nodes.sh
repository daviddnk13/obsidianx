#!/bin/bash
# ==============================================================================
# ObsidianX (OBX) - Script 08 v4.1: Nodos Económicos + Privacidad Tor Real
# ==============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OBX-NET]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -d "$ROOT_DIR/core-chain/build/release/bin" ]; then
    BIN_DIR="$ROOT_DIR/core-chain/build/release/bin"
elif [ -d "$HOME/obsidianx/core-chain/build/release/bin" ]; then
    BIN_DIR="$HOME/obsidianx/core-chain/build/release/bin"
else
    BIN_DIR="${OBX_BIN_DIR:-$ROOT_DIR/bin}"
fi

DAEMON="$BIN_DIR/monerod"
[ -f "$BIN_DIR/obsidianxd" ] && DAEMON="$BIN_DIR/obsidianxd"

DATA_ROOT="${OBX_DATA_ROOT:-$ROOT_DIR/network-nodes}"
MODE="${1:-local-eco}"
PEER_ADDR="${2:-}"

if [ ! -f "$DAEMON" ]; then
    warn "No se encontró el binario compilado en $DAEMON"
    echo "Compila primero en GitHub Actions (build_obsidianx.yml) y coloca obsidianxd en $BIN_DIR"
    exit 1
fi

mkdir -p "$DATA_ROOT/node1" "$DATA_ROOT/android-node" "$DATA_ROOT/logs"

# Flags de ahorro de disco/RAM/datos + proteccion contra apagones
ECO_FLAGS="--db-sync-mode safe:sync --prune-blockchain --no-igd --hide-my-port --max-concurrency 1 --limit-rate-up 64 --limit-rate-down 128"

# Si Tor esta activo (puerto SOCKS 9050), activar --tx-proxy y --anonymous-inbound en puerto 28084
TOR_FLAGS=""
ONION_FILE="$HOME/.obsidianx/tor_service/hidden_service/hostname"
if ss -tln 2>/dev/null | grep -q ":9050 " || nc -z 127.0.0.1 9050 2>/dev/null; then
    TOR_FLAGS="--tx-proxy tor,127.0.0.1:9050"
    if [ -f "$ONION_FILE" ]; then
        MY_ONION=$(cat "$ONION_FILE" | tr -d '[:space:]')
        TOR_FLAGS="$TOR_FLAGS --anonymous-inbound ${MY_ONION}:28084,127.0.0.1:28084,16"
        log "Tor detectado -> Activando privacidad P2P (.onion:28084)"
    fi
fi

if [ "$MODE" == "local-eco" ] || [ "$MODE" == "local-3" ]; then
    log "Iniciando Nodo Principal en modo Económico/Anti-Apagón..."
    "$DAEMON" --data-dir "$DATA_ROOT/node1" \
        --p2p-bind-ip 0.0.0.0 --p2p-bind-port 28080 \
        --rpc-bind-ip 127.0.0.1 --rpc-bind-port 28081 \
        --non-interactive $ECO_FLAGS $TOR_FLAGS \
        --log-file "$DATA_ROOT/logs/node1.log" --detach

    log "Iniciando Agente IA Guardián..."
    python3 "$SCRIPT_DIR/obx_ai_guardian.py" --rpc-port 28081 --low-power &
elif [ "$MODE" == "android" ]; then
    log "Iniciando Nodo Android (Termux) en modo ultra-ahorro de batería y datos..."
    PRIORITY_ARG=""
    [ -n "$PEER_ADDR" ] && PRIORITY_ARG="--add-priority-node $PEER_ADDR"
    "$DAEMON" --data-dir "$DATA_ROOT/android-node" \
        --p2p-bind-ip 0.0.0.0 --p2p-bind-port 28080 \
        --rpc-bind-ip 127.0.0.1 --rpc-bind-port 28081 \
        $PRIORITY_ARG \
        --non-interactive $ECO_FLAGS $TOR_FLAGS \
        --log-file "$DATA_ROOT/logs/android.log" --detach

    python3 "$SCRIPT_DIR/obx_ai_guardian.py" --rpc-port 28081 --low-power
fi
