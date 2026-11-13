#!/bin/bash
# ==============================================================================
# ObsidianX (OBX) - Script 08: Nacimiento de la Cadena con 3 Nodos (Sin mover nada)
# ==============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()    { echo -e "${GREEN}[OBX-NET]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }

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
MODE="${1:-local-3}"
MINER_ADDRESS="${2:-}"

if [ ! -f "$DAEMON" ]; then
    warn "No se encontró el binario compilado en $DAEMON"
    echo "Ejecuta primero la opción [1] de INICIAR_AQUI para compilar o descarga el binario desde GitHub Codespaces/Actions."
    exit 1
fi

mkdir -p "$DATA_ROOT/node1" "$DATA_ROOT/node2" "$DATA_ROOT/node3" "$DATA_ROOT/logs"
SAFE_DB_FLAGS="--db-sync-mode safe:sync --no-igd --hide-my-port"

if [ "$MODE" == "local-3" ]; then
    log "Iniciando los 3 Nodos en $DATA_ROOT (Sin mover archivos)..."

    "$DAEMON" --data-dir "$DATA_ROOT/node1" \
        --p2p-bind-ip 0.0.0.0 --p2p-bind-port 28080 \
        --rpc-bind-ip 127.0.0.1 --rpc-bind-port 28081 \
        --add-priority-node 127.0.0.1:28180 \
        --add-priority-node 127.0.0.1:28280 \
        --non-interactive $SAFE_DB_FLAGS \
        --log-file "$DATA_ROOT/logs/node1.log" --detach

    "$DAEMON" --data-dir "$DATA_ROOT/node2" \
        --p2p-bind-ip 0.0.0.0 --p2p-bind-port 28180 \
        --rpc-bind-ip 127.0.0.1 --rpc-bind-port 28181 \
        --add-priority-node 127.0.0.1:28080 \
        --add-priority-node 127.0.0.1:28280 \
        --non-interactive $SAFE_DB_FLAGS \
        --log-file "$DATA_ROOT/logs/node2.log" --detach

    "$DAEMON" --data-dir "$DATA_ROOT/node3" \
        --p2p-bind-ip 0.0.0.0 --p2p-bind-port 28280 \
        --rpc-bind-ip 127.0.0.1 --rpc-bind-port 28281 \
        --add-priority-node 127.0.0.1:28080 \
        --add-priority-node 127.0.0.1:28180 \
        --non-interactive $SAFE_DB_FLAGS \
        --log-file "$DATA_ROOT/logs/node3.log" --detach

    sleep 3
    log "✅ Los 3 Nodos están encendidos y conectados entre sí."

    if [ -n "$MINER_ADDRESS" ]; then
        log "Minando primeros bloques hacia: $MINER_ADDRESS"
        curl -s -X POST http://127.0.0.1:28081/json_rpc \
            -d "{\"jsonrpc\":\"2.0\",\"id\":\"0\",\"method\":\"start_mining\",\"params\":{\"miner_address\":\"$MINER_ADDRESS\",\"threads_count\":1}}" \
            -H 'Content-Type: application/json'
        echo ""
    fi

    log "Iniciando Agente de IA Guardián..."
    python3 "$SCRIPT_DIR/obx_ai_guardian.py" --rpc-port 28081 &
elif [ "$MODE" == "android" ]; then
    LAPTOP_IP="${2:-192.168.43.1}"
    "$DAEMON" --data-dir "$DATA_ROOT/android-node" \
        --p2p-bind-ip 0.0.0.0 --p2p-bind-port 28080 \
        --rpc-bind-ip 127.0.0.1 --rpc-bind-port 28081 \
        --add-priority-node "$LAPTOP_IP:28080" \
        --prune-blockchain --max-concurrency 1 \
        --non-interactive $SAFE_DB_FLAGS \
        --log-file "$DATA_ROOT/logs/android.log" --detach
    python3 "$SCRIPT_DIR/obx_ai_guardian.py" --rpc-port 28081 --low-power
fi
