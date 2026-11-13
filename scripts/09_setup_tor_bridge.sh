#!/bin/bash
# ==============================================================================
# ObsidianX (OBX) - Script 09: Puente Tor (.onion) Gratuito sin VPS
# ==============================================================================
# Crea un Hidden Service de Tor en tu Laptop o Android (Termux) para que tu nodo
# tenga una dirección fija .onion gratuita que atraviesa cualquier NAT/Firewall
# de ETECSA sin abrir puertos ni pagar servidores VPS.
# ==============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log() { echo -e "${GREEN}[OBX-TOR]${NC} $1"; }

TOR_DIR="$HOME/.obsidianx/tor_service"
mkdir -p "$TOR_DIR/hidden_service"
chmod 700 "$TOR_DIR/hidden_service"

cat > "$TOR_DIR/torrc" << EOF
DataDirectory $TOR_DIR/data
HiddenServiceDir $TOR_DIR/hidden_service
HiddenServicePort 28080 127.0.0.1:28080
HiddenServicePort 28081 127.0.0.1:28081
SocksPort 9050
EOF

log "Configuración Tor generada en $TOR_DIR/torrc"
if command -v tor >/dev/null 2>&1; then
    tor -f "$TOR_DIR/torrc" --RunAsDaemon 1
    sleep 4
    if [ -f "$TOR_DIR/hidden_service/hostname" ]; then
        ONION_ADDR=$(cat "$TOR_DIR/hidden_service/hostname")
        log "✅ Tu dirección fija de Nodo ObsidianX (100% gratis, sin VPS) es:"
        echo ""
        echo "    $ONION_ADDR:28080"
        echo ""
        log "Comparte esta dirección con el móvil Android o con amigos para conectarse desde cualquier lugar."
    fi
else
    echo -e "${YELLOW}[NOTA]${NC} Instala Tor con 'sudo apt install tor' (en PC) o 'pkg install tor' (en Android Termux) y vuelve a ejecutar este script."
fi
