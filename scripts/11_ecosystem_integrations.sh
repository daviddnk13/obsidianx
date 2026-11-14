#!/bin/bash
# ==============================================================================
# ObsidianX (OBX) - Script 11 (v6.1): Integraciones Plug & Play sin Refactorizar
# ==============================================================================
set -e

GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${GREEN}[OBX-ECO]${NC} $1"; }

MOD="${1:-help}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EXT_DIR="$ROOT_DIR/ecosystem"
mkdir -p "$EXT_DIR"

case "$MOD" in
  xmrig-proxy)
    mkdir -p "$EXT_DIR/xmrig-proxy"
    cat > "$EXT_DIR/xmrig-proxy/config.json" << 'EOF'
{
  "access-log-file": null,
  "bind": [
    { "host": "0.0.0.0", "port": 3333, "tls": false }
  ],
  "custom-diff": 100,
  "donate-level": 0,
  "MODE": "simple",
  "pools": [
    {
      "algo": "rx/0",
      "coin": "monero",
      "url": "127.0.0.1:28081",
      "user": "TU_DIRECCION_OBX",
      "daemon": true
    }
  ]
}
EOF
    log "Configuración xmrig-proxy lista en $EXT_DIR/xmrig-proxy/config.json"
    ;;
  lws)
    mkdir -p "$EXT_DIR/lws-data"
    cat > "$EXT_DIR/run_lws.sh" << EOF
#!/bin/bash
monero-lws-daemon --db-path "$EXT_DIR/lws-data" --daemon "tcp://127.0.0.1:28083" --rest-server "http://127.0.0.1:8443"
EOF
    chmod +x "$EXT_DIR/run_lws.sh"
    log "Lanzador LWS creado en $EXT_DIR/run_lws.sh"
    ;;
  p2pool)
    cat > "$EXT_DIR/run_p2pool.sh" << 'EOF'
#!/bin/bash
WALLET="${1:?Uso: ./run_p2pool.sh TU_DIRECCION_OBX}"
./p2pool --host 127.0.0.1 --rpc-port 28081 --zmq-port 28083 --wallet "$WALLET" --stratum 0.0.0.0:3333 --no-cache
EOF
    chmod +x "$EXT_DIR/run_p2pool.sh"
    log "Lanzador P2Pool creado en $EXT_DIR/run_p2pool.sh"
    ;;
  atomic-swap)
    cat > "$EXT_DIR/run_atomic_swap_seller.sh" << 'EOF'
#!/bin/bash
./asb start --monero-daemon-address http://127.0.0.1:28081 --monero-wallet-rpc-address http://127.0.0.1:28088
EOF
    chmod +x "$EXT_DIR/run_atomic_swap_seller.sh"
    log "Plantilla Atomic Swap creada en $EXT_DIR/run_atomic_swap_seller.sh"
    ;;
  *)
    echo -e "${CYAN}Uso: bash scripts/11_ecosystem_integrations.sh [xmrig-proxy | lws | p2pool | atomic-swap]${NC}"
    ;;
esac
