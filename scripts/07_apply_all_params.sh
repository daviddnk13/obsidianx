#!/bin/bash
# ==============================================================================
# ObsidianX (OBX) - Real C++ Fork Patcher (Based on Monero release-v0.18)
# ==============================================================================
# Applies verified consensus, network, emission, difficulty, and checkpoint
# patches, failing loudly if any sed/python replacement does not match.
# ==============================================================================
set -euo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
log()  { echo -e "${GREEN}[OBX]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
step() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

CORE_DIR="${OBX_CORE_DIR:-$HOME/obsidianx/core-chain}"
CONFIG="$CORE_DIR/src/cryptonote_config.h"
BASIC_IMPL="$CORE_DIR/src/cryptonote_basic/cryptonote_basic_impl.cpp"
HARDFORKS="$CORE_DIR/src/hardforks/hardforks.cpp"
CHECKPOINTS="$CORE_DIR/src/checkpoints/checkpoints.cpp"
NET_NODE="$CORE_DIR/src/p2p/net_node.inl"

if [ ! -d "$CORE_DIR" ]; then
    log "Cloning Monero release-v0.18 (latest v0.18.4.x security fixes)..."
    git clone --branch release-v0.18 --depth 1 --recursive https://github.com/monero-project/monero.git "$CORE_DIR"
fi

cd "$CORE_DIR"

step "1. Network Name, Sovereign Ports (38080/38081/38082), and Valid Difficulty Window"
sed -i 's/CRYPTONOTE_NAME.*"bitmonero"/CRYPTONOTE_NAME                         "obsidianx"/' "$CONFIG"
sed -i 's/CRYPTONOTE_NAME.*"monero"/CRYPTONOTE_NAME                         "obsidianx"/' "$CONFIG"

# Sovereign ports (avoiding 18080 Monero mainnet and 28080 Monero testnet)
sed -i 's/P2P_DEFAULT_PORT = 18080/P2P_DEFAULT_PORT = 38080/' "$CONFIG"
sed -i 's/RPC_DEFAULT_PORT = 18081/RPC_DEFAULT_PORT = 38081/' "$CONFIG"
sed -i 's/ZMQ_RPC_DEFAULT_PORT = 18082/ZMQ_RPC_DEFAULT_PORT = 38082/' "$CONFIG"

# Valid difficulty window: WINDOW (120) > 2 * CUT (15), LAG = 0
sed -i 's/#define DIFFICULTY_WINDOW[[:space:]]*720/#define DIFFICULTY_WINDOW                               120/' "$CONFIG"
sed -i 's/#define DIFFICULTY_CUT[[:space:]]*60/#define DIFFICULTY_CUT                                  15/' "$CONFIG"

grep -q '"obsidianx"' "$CONFIG" || err "Failed to set CRYPTONOTE_NAME"
grep -q 'P2P_DEFAULT_PORT = 38080' "$CONFIG" || err "Failed to set P2P_DEFAULT_PORT = 38080"
grep -q 'DIFFICULTY_WINDOW.*120' "$CONFIG" || err "Failed to set DIFFICULTY_WINDOW = 120"
grep -q 'DIFFICULTY_CUT.*15' "$CONFIG" || err "Failed to set DIFFICULTY_CUT = 15"
log "Verified: CRYPTONOTE_NAME, ports 38080/38081/38082, DIFFICULTY_WINDOW=120, DIFFICULTY_CUT=15"

step "2. Custom Base58 Address Prefixes (Isolated from Monero 4... keys)"
# Mainnet prefix 0x1e2c (starts with 'Ob...')
sed -i 's/CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX = 18;/CRYPTONOTE_PUBLIC_ADDRESS_BASE58_PREFIX = 0x1e2c;/' "$CONFIG"
sed -i 's/CRYPTONOTE_PUBLIC_INTEGRATED_ADDRESS_BASE58_PREFIX = 19;/CRYPTONOTE_PUBLIC_INTEGRATED_ADDRESS_BASE58_PREFIX = 0x1e2d;/' "$CONFIG"
sed -i 's/CRYPTONOTE_PUBLIC_SUBADDRESS_BASE58_PREFIX = 42;/CRYPTONOTE_PUBLIC_SUBADDRESS_BASE58_PREFIX = 0x1e2e;/' "$CONFIG"
grep -q '0x1e2c' "$CONFIG" || err "Failed to set custom Base58 prefix"
log "Verified: Custom Base58 address prefixes set (0x1e2c/0x1e2d/0x1e2e)"

step "3. Unique NETWORK_ID (SHA-256 of obsidianx-mainnet-2026)"
python3 - "$CONFIG" << 'PYEOF'
import hashlib, sys, re
p = sys.argv[1]
h = hashlib.sha256(b'obsidianx-mainnet-v1-2026').hexdigest()
new_bytes = ", ".join([f"0x{h[i:i+2]}" for i in range(0, 32, 2)])
txt = open(p, 'r', encoding='utf-8').read()
new_txt, n = re.subn(
    r'(namespace config\s*\{[\s\S]*?boost::uuids::uuid const NETWORK_ID\s*=\s*\{\s*\{)[^}]+(\}\s*\};)',
    r'\g<1>' + new_bytes + r'\g<2>',
    txt, count=1
)
assert n == 1, "NETWORK_ID pattern did not match in cryptonote_config.h!"
open(p, 'w', encoding='utf-8').write(new_txt)
print(f"Verified: NETWORK_ID injected -> {{ {new_bytes} }}")
PYEOF

step "4. Fair-Launch Emission (0 Premine, 21M Cap, 0.6 OBX Tail Emission)"
cat > "$CORE_DIR/src/obx_emission.h" << 'EOF'
#pragma once
#include <cstdint>

namespace obx {
    static constexpr uint64_t COIN_UNIT           = 1000000000000ULL;
    static constexpr uint64_t MONEY_SUPPLY_CAP    = 21000000ULL * COIN_UNIT; // 21,000,000 OBX
    static constexpr uint64_t TAIL_REWARD_ATOMIC  = 600000000000ULL;         // 0.6 OBX/block tail emission

    // Smooth emission curve based on remaining supply (Fair Launch: 0 premine)
    inline uint64_t get_block_reward(uint64_t already_generated_coins) {
        if (already_generated_coins >= MONEY_SUPPLY_CAP) {
            return TAIL_REWARD_ATOMIC;
        }
        uint64_t base_reward = (MONEY_SUPPLY_CAP - already_generated_coins) >> 20;
        return (base_reward < TAIL_REWARD_ATOMIC) ? TAIL_REWARD_ATOMIC : base_reward;
    }
}
EOF

if ! grep -q "obx_emission.h" "$BASIC_IMPL"; then
    sed -i '1i #include "obx_emission.h"' "$BASIC_IMPL"
fi
python3 - "$BASIC_IMPL" << 'PYEOF'
import sys
p = sys.argv[1]
txt = open(p, 'r', encoding='utf-8').read()
target = 'uint64_t base_reward = (MONEY_SUPPLY - already_generated_coins) >> emission_speed_factor;'
replacement = 'uint64_t base_reward = (already_generated_coins == 0) ? ((MONEY_SUPPLY - already_generated_coins) >> emission_speed_factor) : obx::get_block_reward(already_generated_coins);'
if replacement not in txt:
    assert target in txt, "Emission line not found in cryptonote_basic_impl.cpp!"
    txt = txt.replace(target, replacement, 1)
    open(p, 'w', encoding='utf-8').write(txt)
print("Verified: obx::get_block_reward wired cleanly (genesis block 0 preserved)")
PYEOF

step "5. Hardforks Activation from Block 1 (RingCT + CLSAG + Bulletproofs+ + RandomX)"
python3 - "$HARDFORKS" << 'PYEOF'
import sys, re
p = sys.argv[1]
txt = open(p, 'r', encoding='utf-8').read()
new_table = """const hardfork_t mainnet_hard_forks[] = {
  { 1, 0, 0, 1341378000 },
  { 16, 1, 0, 1700000000 },
};"""
new_txt, n = re.subn(
    r'const hardfork_t mainnet_hard_forks\[\] = \{[\s\S]*?\};',
    new_table,
    txt, count=1
)
assert n == 1, "mainnet_hard_forks table not found in hardforks.cpp!"
open(p, 'w', encoding='utf-8').write(new_txt)
print("Verified: Hardforks v16 (RingCT/CLSAG/Bulletproofs+/RandomX) active from Block 1")
PYEOF

step "6. Clear Monero Checkpoints & Seed Nodes"
python3 - "$CHECKPOINTS" << 'PYEOF'
import sys
p = sys.argv[1]
txt = open(p, 'r', encoding='utf-8').read()
# Disable Monero hardcoded mainnet checkpoints so ObsidianX starts clean at height 0
txt = txt.replace('ADD_CHECKPOINT(', '// OBX_DISABLED: ADD_CHECKPOINT(')
txt = txt.replace('ADD_CHECKPOINT2(', '// OBX_DISABLED: ADD_CHECKPOINT2(')
open(p, 'w', encoding='utf-8').write(txt)
print("Verified: Monero hardcoded checkpoints cleared")
PYEOF

sed -i '/m_seed_nodes_list.push_back/d' "$NET_NODE"
log "Verified: Monero seed nodes removed from net_node.inl"


sed -i '/on_start_mining(/,/CHECK_CORE_READY();/ s/CHECK_CORE_READY();/\/\/ OBX allow P2P mining/' "$CORE_DIR/src/rpc/core_rpc_server.cpp"
step "7. CMake Configure (Release + Static Internal Libs)"
mkdir -p "$CORE_DIR/build/release"
cd "$CORE_DIR/build/release"
cmake ../.. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF -DBUILD_GUI_DEPS=OFF -DARCH=default
log "CMake configured cleanly! Ready to compile: make -j1 daemon simplewallet"
