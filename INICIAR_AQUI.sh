#!/bin/bash
# ==============================================================================
# OBSIDIANX (OBX) - LANZADOR AUTOMATICO PARA LINUX / WSL / ANDROID TERMUX
# ==============================================================================
# No necesitas mover ninguna carpeta. Ejecutalo directamente desde donde
# descomprimiste el ZIP:
#   bash INICIAR_AQUI.sh
# ==============================================================================
set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"
chmod +x "$BASE_DIR/scripts/"*.sh "$BASE_DIR/scripts/"*.py 2>/dev/null || true

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   OBSIDIANX (OBX) - LANZADOR AUTOMATICO (SIN MOVER CARPETAS)${NC}"
echo -e "${CYAN}   Ubicación actual: $BASE_DIR${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}¿Qué deseas ejecutar ahora mismo?${NC}"
echo "  [1] Descargar Monero base aquí mismo, aplicar parches OBX y compilar"
echo "  [2] Crear mi Billetera Génesis OBX"
echo "  [3] Encender los 3 Nodos + Agente IA Guardián (Nacer la cadena)"
echo "  [4] Activar Puente Tor (.onion) gratis sin VPS"
echo "  [5] Conectar como Nodo Móvil desde Android (Termux)"
echo ""
read -p "Elige una opción (1-5): " OPCION

export OBX_CORE_DIR="$BASE_DIR/core-chain"
export OBX_BIN_DIR="$BASE_DIR/core-chain/build/release/bin"
export OBX_DATA_ROOT="$BASE_DIR/network-nodes"

case "$OPCION" in
  1)
    if [ ! -d "$OBX_CORE_DIR" ]; then
      echo -e "${GREEN}[OBX] Descargando código base de Monero v0.18.3.3 en $OBX_CORE_DIR...${NC}"
      git clone --branch v0.18.3.3 --depth 1 --recursive https://github.com/monero-project/monero.git "$OBX_CORE_DIR"
    fi
    "$BASE_DIR/scripts/07_apply_all_params.sh"
    echo -e "${GREEN}[OBX] Iniciando compilación resistente a apagones...${NC}"
    cd "$OBX_CORE_DIR/build/release"
    make -j2 daemon simplewallet 2>&1 | tee -a "$BASE_DIR/compile.log"
    ;;
  2)
    "$OBX_BIN_DIR/monero-wallet-cli" --generate-new-wallet "$BASE_DIR/mi_billetera_genesis"
    ;;
  3)
    read -p "Pega tu dirección OBX (o Enter para iniciar sin minar aún): " ADDR
    "$BASE_DIR/scripts/08_launch_3_nodes.sh" local-3 "$ADDR"
    ;;
  4)
    "$BASE_DIR/scripts/09_setup_tor_bridge.sh"
    ;;
  5)
    read -p "Escribe la IP o dirección .onion del Nodo Principal: " PEER
    "$BASE_DIR/scripts/08_launch_3_nodes.sh" android "$PEER"
    ;;
  *)
    echo "Opción no válida."
    ;;
esac
