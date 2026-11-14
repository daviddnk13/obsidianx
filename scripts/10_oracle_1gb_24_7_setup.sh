#!/bin/bash
# ==============================================================================
# ObsidianX (OBX) - Script 10 (v6.1): Instalador Nodo 24/7 en Oracle VM 1GB RAM
# ==============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${GREEN}[OBX-ORACLE]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATA_DIR="$ROOT_DIR/oracle-node-data"
BIN_DIR="$ROOT_DIR/bin"
mkdir -p "$DATA_DIR" "$BIN_DIR"

log "1/5 Verificando memoria Swap de 1 GB para estabilidad en VM de 1 GB RAM..."
if ! sudo swapon --show | grep -q "/swapfile"; then
    sudo fallocate -l 1G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    grep -q "/swapfile" /etc/fstab || echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
    log "Swap de 1 GB activado."
else
    log "Swap ya estaba activo."
fi

log "2/5 Instalando dependencias ligeras (Tor, Python3, vnstat para auditar tráfico)..."
sudo apt-get update -y
sudo apt-get install -y tor python3 curl vnstat

log "3/5 Configurando Puente Tor (.onion:28084 y :28080)..."
bash "$SCRIPT_DIR/09_setup_tor_bridge.sh"
ONION_FILE="$HOME/.obsidianx/tor_service/hidden_service/hostname"
MY_ONION=""
[ -f "$ONION_FILE" ] && MY_ONION=$(tr -d '[:space:]' < "$ONION_FILE")

log "4/5 Creando servicios systemd 24/7 con límite estricto de tráfico (16 KB/s up / 32 KB/s down)..."
USER_NAME="$(whoami)"

if [ -f "$BIN_DIR/obsidianxd" ]; then
    TOR_ARGS="--tx-proxy tor,127.0.0.1:9050"
    [ -n "$MY_ONION" ] && TOR_ARGS="$TOR_ARGS --anonymous-inbound ${MY_ONION}:28084,127.0.0.1:28084,16"

    sudo tee /etc/systemd/system/obsidianxd.service >/dev/null << EOF
[Unit]
Description=ObsidianX (OBX) 24/7 Seed Node (Oracle 1GB Eco Mode)
After=network.target tor.service

[Service]
User=$USER_NAME
Nice=19
CPUQuota=40%
MemoryMax=600M
ExecStart=$BIN_DIR/obsidianxd --data-dir $DATA_DIR --p2p-bind-ip 0.0.0.0 --p2p-bind-port 28080 --rpc-bind-ip 127.0.0.1 --rpc-bind-port 28081 --zmq-pub tcp://127.0.0.1:28083 --prune-blockchain --db-sync-mode safe:sync --no-igd --hide-my-port --max-concurrency 1 --limit-rate-up 16 --limit-rate-down 32 $TOR_ARGS --non-interactive
Restart=always
RestartSec=15

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable --now obsidianxd
    log "Servicio obsidianxd 24/7 activado."
else
    echo -e "${YELLOW}[AVISO]${NC} Coloca el binario compilado 'obsidianxd' dentro de $BIN_DIR y vuelve a correr este script."
fi

sudo tee /etc/systemd/system/obsidianx-guardian.service >/dev/null << EOF
[Unit]
Description=ObsidianX AI Guardian v3.0 (Autonomous P2P Shield)
After=network.target

[Service]
User=$USER_NAME
Nice=19
ExecStart=/usr/bin/python3 $SCRIPT_DIR/obx_ai_guardian.py --rpc-port 28081 --low-power
Restart=always
RestartSec=20

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now obsidianx-guardian
log "5/5 Agente IA Guardián v3.0 activo 24/7 en systemd."
