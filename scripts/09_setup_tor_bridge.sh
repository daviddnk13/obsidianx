#!/bin/bash
# ==============================================================================
# ObsidianX (OBX) - Script 09 v4.1: Puente Tor (.onion) con puerto anonimo 28084
# ==============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[OBX-TOR]${NC} $1"; }

TOR_DIR="$HOME/.obsidianx/tor_service"
mkdir -p "$TOR_DIR/hidden_service" "$TOR_DIR/data"
chmod 700 "$TOR_DIR/hidden_service"

cat > "$TOR_DIR/torrc" << 'TOR_EOF'
DataDirectory __TOR_DIR__/data
HiddenServiceDir __TOR_DIR__/hidden_service
# Puerto separado (28084) para --anonymous-inbound segun especificacion Monero
HiddenServicePort 28084 127.0.0.1:28084
HiddenServicePort 28080 127.0.0.1:28080
SocksPort 9050
TOR_EOF
sed -i "s|__TOR_DIR__|$TOR_DIR|g" "$TOR_DIR/torrc"

log "Configuración Tor guardada en $TOR_DIR/torrc"
if command -v tor >/dev/null 2>&1; then
    tor -f "$TOR_DIR/torrc" --RunAsDaemon 1
    sleep 4
    if [ -f "$TOR_DIR/hidden_service/hostname" ]; then
        ONION_ADDR=$(cat "$TOR_DIR/hidden_service/hostname" | tr -d '[:space:]')
        log "Dirección .onion lista:"
        echo "  Relay anónimo (--anonymous-inbound): ${ONION_ADDR}:28084,127.0.0.1:28084,16"
        echo "  Par prioritario (--add-priority-node): ${ONION_ADDR}:28080"
    fi
else
    echo -e "${YELLOW}[NOTA]${NC} Instala Tor primero ('sudo apt install tor' en Linux o 'pkg install tor' en Termux)."
fi
