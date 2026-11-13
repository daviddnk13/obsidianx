#!/bin/bash
set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()    { echo -e "${GREEN}[OBX]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE} $1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}"; }

CORE_DIR="$HOME/obsidianx/core-chain"
CONFIG="$CORE_DIR/src/cryptonote_config.h"
cd $CORE_DIR

header "PASO 1: Nombre obsidianx"
sed -i 's/CRYPTONOTE_NAME.*"bitmonero"/CRYPTONOTE_NAME                         "obsidianx"/' $CONFIG
sed -i 's/CRYPTONOTE_NAME.*"monero"/CRYPTONOTE_NAME                         "obsidianx"/' $CONFIG
grep "CRYPTONOTE_NAME" $CONFIG | head -1
log "Nombre OK"

header "PASO 2: Ticker OBX"
find $CORE_DIR/src -name "*.cpp" -o -name "*.h" | xargs grep -l '"XMR"' 2>/dev/null | while read f; do
    sed -i 's/"XMR"/"OBX"/g' "$f"
done
log "Ticker OBX OK"

header "PASO 3: Archivo de emisión OBX"
cat > $CORE_DIR/src/obx_emission.h << 'EOF'
#pragma once
#include <cstdint>
namespace obx {
    static constexpr uint64_t TOTAL_SUPPLY_ATOMIC   = 18400000ULL * 1000000000000ULL;
    static constexpr uint64_t INITIAL_REWARD_ATOMIC = 20ULL * 1000000000000ULL;
    static constexpr uint64_t REDUCTION_INTERVAL    = 100000ULL;
    static constexpr uint64_t REDUCTION_NUMERATOR   = 9;
    static constexpr uint64_t REDUCTION_DENOMINATOR = 10;
    static constexpr uint64_t MIN_REWARD_ATOMIC     = 1000000000ULL;
    static constexpr uint64_t DEV_FUND_ATOMIC       = 920000ULL * 1000000000000ULL;
    inline uint64_t get_block_reward(uint64_t height) {
        uint64_t intervals = height / REDUCTION_INTERVAL;
        uint64_t reward    = INITIAL_REWARD_ATOMIC;
        for (uint64_t i = 0; i < intervals; ++i) {
            reward = reward * REDUCTION_NUMERATOR / REDUCTION_DENOMINATOR;
        }
        return (reward < MIN_REWARD_ATOMIC) ? MIN_REWARD_ATOMIC : reward;
    }
}
EOF
log "Emisión OBX OK"

header "PASO 4: Mensaje génesis"
find $CORE_DIR/src -name "*.cpp" | xargs grep -l "Monero is not a backdoor" 2>/dev/null | while read f; do
    sed -i 's/Monero is not a backdoor/ObsidianX - Privacy is not a crime - 2024/' "$f"
    log "Génesis: $f"
done
log "Génesis OK"

header "PASO 5: Network ID único"
python3 -c "
import hashlib
h = hashlib.sha256('obsidianx-mainnet-2024'.encode()).hexdigest()
b = [f'0x{h[i:i+2]}' for i in range(0,32,2)]
print('  Network ID: {' + ', '.join(b) + '}')
"

header "PASO 6: Commit Git"
git add -A
git commit -m "feat: apply ObsidianX parameters - OBX fork from Monero v0.18.3.3"
log "Commit OK"

header "PASO 7: CMake configure"
mkdir -p $CORE_DIR/build/release
cd $CORE_DIR/build/release
cmake ../.. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF -DBUILD_GUI_DEPS=OFF -DARCH=default 2>&1 | tail -3
log "CMake OK"

header "✅ TODO LISTO — Ejecutar compilación:"
echo ""
echo "  cd ~/obsidianx/core-chain/build/release"
echo "  make -j2 daemon wallet_cli 2>&1 | tee ~/obsidianx/testnet-data/logs/compile.log"
echo ""
echo -e "  ${RED}TIEMPO: 60-90 minutos${NC}"
