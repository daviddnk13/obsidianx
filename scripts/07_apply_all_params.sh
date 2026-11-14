#!/bin/bash
set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()    { echo -e "${GREEN}[OBX]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
header() { echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE} $1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}"; }

CORE_DIR="$HOME/obsidianx/core-chain"
CONFIG="$CORE_DIR/src/cryptonote_config.h"
cd "$CORE_DIR"

header "PASO 1: Nombre, Puertos (28080/28081) y Dificultad Anti-Apagones"
sed -i 's/CRYPTONOTE_NAME.*"bitmonero"/CRYPTONOTE_NAME                         "obsidianx"/' "$CONFIG"
sed -i 's/CRYPTONOTE_NAME.*"monero"/CRYPTONOTE_NAME                         "obsidianx"/' "$CONFIG"
sed -i 's/P2P_DEFAULT_PORT[[:space:]]*18080/P2P_DEFAULT_PORT 28080/g' "$CONFIG"
sed -i 's/RPC_DEFAULT_PORT[[:space:]]*18081/RPC_DEFAULT_PORT 28081/g' "$CONFIG"
sed -i 's/DIFFICULTY_WINDOW[[:space:]]*720/DIFFICULTY_WINDOW 60/g' "$CONFIG"
grep "CRYPTONOTE_NAME" "$CONFIG" | head -1
log "Configuración base y ventana de 60 bloques OK"

header "PASO 2: Ticker OBX"
(find "$CORE_DIR/src" \( -name "*.cpp" -o -name "*.h" \) -print0 | xargs -0 grep -l '"XMR"' 2>/dev/null || true) | while read -r f; do
    sed -i 's/"XMR"/"OBX"/g' "$f"
done
log "Ticker OBX OK"

header "PASO 3: Emisión OBX (obx_emission.h) conectada al consenso"
cat > "$CORE_DIR/src/obx_emission.h" << 'INNER_EOF'
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
    inline uint64_t get_block_reward(uint64_t height, bool &override_active) {
        override_active = true;
        if (height == 1) return DEV_FUND_ATOMIC;
        uint64_t intervals = height / REDUCTION_INTERVAL;
        uint64_t reward    = INITIAL_REWARD_ATOMIC;
        for (uint64_t i = 0; i < intervals; ++i) {
            reward = reward * REDUCTION_NUMERATOR / REDUCTION_DENOMINATOR;
        }
        return (reward < MIN_REWARD_ATOMIC) ? MIN_REWARD_ATOMIC : reward;
    }
}
INNER_EOF

IMPL_FILE="$CORE_DIR/src/cryptonote_basic/cryptonote_basic_impl.cpp"
if [ -f "$IMPL_FILE" ]; then
    if ! grep -q "obx_emission.h" "$IMPL_FILE"; then
        sed -i '1i #include "obx_emission.h"' "$IMPL_FILE"
    fi
    # Inyectar retorno directo de obx::get_block_reward al inicio de get_block_reward(...)
    python3 - "$IMPL_FILE" << 'PYEOF'
import sys, re
p = sys.argv[1]
with open(p, "r", encoding="utf-8") as f:
    txt = f.read()
if "obx::get_block_reward" not in txt:
    pattern = r'(bool\s+get_block_reward\s*\([^)]*\)\s*\{)'
    replacement = r'\1\n    bool obx_ok = false;\n    uint64_t obx_rew = obx::get_block_reward(already_generated_coins == 0 ? 0 : 2, obx_ok);\n    if (obx_ok && already_generated_coins == 0) { reward = obx_rew; return true; }'
    # Mejor: usar height si esta disponible, o reemplazar el calculo de base_reward
    new_txt, n = re.subn(
        r'(bool\s+get_block_reward\s*\([^)]*uint64_t\s+already_generated_coins[^)]*\)\s*\{)',
        r'\1\n    // ObsidianX (OBX) Emission Hook\n    if (already_generated_coins == 0) { reward = obx::INITIAL_REWARD_ATOMIC; return true; }\n    if (already_generated_coins == obx::INITIAL_REWARD_ATOMIC) { reward = obx::DEV_FUND_ATOMIC; return true; }',
        txt,
        count=1
    )
    with open(p, "w", encoding="utf-8") as f:
        f.write(new_txt)
    print(f"Hook de emision OBX inyectado en cryptonote_basic_impl.cpp (coincidencias: {n})")
else:
    print("Hook de emision OBX ya estaba presente.")
PYEOF
fi

header "PASO 4: Network ID único inyectado en cryptonote_config.h"
NET_BYTES=$(python3 -c "import hashlib; h=hashlib.sha256(b'obsidianx-mainnet-2024').hexdigest(); print(', '.join(f'0x{h[i:i+2]}' for i in range(0,32,2)))")
log "Network ID generado: {$NET_BYTES}"
python3 - "$CONFIG" "$NET_BYTES" << 'PYEOF'
import sys, re
cfg, net_bytes = sys.argv[1], sys.argv[2]
with open(cfg, "r", encoding="utf-8") as f:
    txt = f.read()
new_txt, n = re.subn(
    r'(NETWORK_ID\s*=\s*\{\{\s*)0x[0-9a-fA-F]{2}(?:\s*,\s*0x[0-9a-fA-F]{2}){15}(\s*\}\})',
    r'\g<1>' + net_bytes + r'\g<2>',
    txt,
    count=1
)
with open(cfg, "w", encoding="utf-8") as f:
    f.write(new_txt)
print(f"NETWORK_ID reemplazado en cryptonote_config.h (coincidencias: {n})")
PYEOF

header "PASO 5: Mensaje génesis (si aplica)"
(find "$CORE_DIR/src" -name "*.cpp" -print0 | xargs -0 grep -l "Monero is not a backdoor" 2>/dev/null || true) | while read -r f; do
    sed -i 's/Monero is not a backdoor/ObsidianX - Privacy is not a crime - 2024/' "$f"
done

header "PASO 6: Commit Git (con identidad segura para CI/GitHub Actions)"
git config user.name "ObsidianX Builder"
git config user.email "builder@obsidianx.local"
git add -A
git diff --staged --quiet || git commit -m "feat: apply ObsidianX v6.0 purified consensus & network params"
log "Commit OK"

header "PASO 7: CMake configure"
mkdir -p "$CORE_DIR/build/release"
cd "$CORE_DIR/build/release"
cmake ../.. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF -DBUILD_GUI_DEPS=OFF -DARCH=default 2>&1 | tail -5
log "CMake OK - Listo para compilar con: make -j\$(nproc) daemon simplewallet"
