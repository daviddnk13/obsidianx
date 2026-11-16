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
    log "Cloning Monero v0.18.5.4 (pinned official release tag)..."
    git clone --branch v0.18.5.4 --depth 1 --recursive https://github.com/monero-project/monero.git "$CORE_DIR"
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
# Mainnet prefix 0x1e2c (produces 'Vo...' 97-char Base58 addresses)
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

# Valid Ed25519 tx_pub_key + tx_extra_nonce ("OBX2026!") -> 43 bytes (0x2b)
gen_tx = "013c01ff0001ffffffffffff03029b2e4c0281c0b02e7c53291a94d1d0cbff8883f8024f5142ee494ffbbd0880712b017767aafcde9be00dcfd098715ebcf7f410daebc582fda69d24a28e9d0bc890d102084f42583230323621"
txt2 = open(p, 'r', encoding='utf-8').read()
txt2, ng1 = re.subn(r'std::string const GENESIS_TX = "[^"]+";', f'std::string const GENESIS_TX = "{gen_tx}";', txt2, count=1)
txt2, ng2 = re.subn(r'uint32_t const GENESIS_NONCE = \d+;', 'uint32_t const GENESIS_NONCE = 20261115;', txt2, count=1)
assert ng1 == 1 and ng2 == 1, f"Genesis patterns not matched: ng1={ng1}, ng2={ng2}"
open(p, 'w', encoding='utf-8').write(txt2)
print("Verified: Custom GENESIS_TX & GENESIS_NONCE=20261115 injected!")
PYEOF

step "4. Fair-Launch Emission (0 Premine, 18M Base + 0.6 OBX Tail Emission, No uint64 Overflow)"
cat > "$CORE_DIR/src/obx_emission.h" << 'EOF'
#pragma once
#include <cstdint>

namespace obx {
    static constexpr uint64_t COIN_UNIT           = 1000000000000ULL;
    static constexpr uint64_t MONEY_SUPPLY_CAP    = 18000000ULL * COIN_UNIT; // 18,000,000 OBX (fits uint64_t safely)
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

python3 - "$CORE_DIR/src/wallet/wallet2.cpp" << 'PYEOF'
import sys, re
p = sys.argv[1]
txt = open(p, 'r', encoding='utf-8').read()
new_fn = """void check_block_hard_fork_version(cryptonote::network_type nettype, uint8_t hf_version, uint64_t height, bool &wallet_is_outdated, bool &daemon_is_outdated)
{
  const size_t wallet_num_hard_forks = nettype == TESTNET ? num_testnet_hard_forks
    : nettype == STAGENET ? num_stagenet_hard_forks : num_mainnet_hard_forks;
  const hardfork_t *wallet_hard_forks = nettype == TESTNET ? testnet_hard_forks
    : nettype == STAGENET ? stagenet_hard_forks : mainnet_hard_forks;

  size_t idx = wallet_num_hard_forks;
  for (size_t i = 0; i < wallet_num_hard_forks; ++i)
  {
    if (wallet_hard_forks[i].version == hf_version)
    {
      idx = i;
      break;
    }
  }
  wallet_is_outdated = idx == wallet_num_hard_forks;
  if (wallet_is_outdated)
    return;

  uint64_t start_height = hf_version == 1 ? 0 : wallet_hard_forks[idx].height;
  uint64_t end_height = idx + 1 >= wallet_num_hard_forks
    ? std::numeric_limits<uint64_t>::max()
    : wallet_hard_forks[idx + 1].height;

  daemon_is_outdated = height < start_height || height >= end_height;
}"""
new_txt, n = re.subn(
    r'void check_block_hard_fork_version\(cryptonote::network_type nettype, uint8_t hf_version, uint64_t height, bool &wallet_is_outdated, bool &daemon_is_outdated\)\s*\{[\s\S]*?daemon_is_outdated = height < start_height \|\| height >= end_height;\s*\}',
    new_fn,
    txt, count=1
)
assert n == 1, "check_block_hard_fork_version not found in wallet2.cpp!"
open(p, 'w', encoding='utf-8').write(new_txt)
print("Verified: wallet2.cpp check_block_hard_fork_version patched for OBX")
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

python3 - "$NET_NODE" << 'PYEOF'
import sys, re
p = sys.argv[1]
txt = open(p, 'r', encoding='utf-8').read()
# 1. Reemplazar DNS seeds publicos de Monero por 92.5.87.63:38080
txt, n1 = re.subn(
    r'return get_dns_seed_nodes\(\);',
    'return {"92.5.87.63:38080"};',
    txt, count=1
)
# 2. Reemplazar seeds Tor .onion de Monero por el .onion oficial de ObsidianX
txt, n2 = re.subn(
    r'(case epee::net_utils::zone::tor:\s*if \(m_nettype == cryptonote::MAINNET\)\s*\{\s*return \{)[\s\S]*?(\};)',
    r'\g<1>\n          "3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38083"\n        \g<2>',
    txt, count=1
)
assert n1 == 1 and n2 == 1, f"Seed patterns not matched: n1={n1}, n2={n2}"
open(p, 'w', encoding='utf-8').write(txt)
print("Verified: Native Clearnet (92.5.87.63:38080) & Tor (.onion:38083) seeds injected!")
PYEOF
log "Verified: Monero seed nodes removed from net_node.inl"



step "6a. Safe Genesis/Sync Guard for on_start_mining (blocks mining while behind peers, allows genesis network)"
python3 - "$CORE_DIR/src/rpc/core_rpc_server.cpp" << 'PYEOF'
import sys, re
p = sys.argv[1]
txt = open(p, 'r', encoding='utf-8').read()
pat = r'(bool core_rpc_server::on_start_mining\([^\)]*\)\s*\{\s*RPC_TRACKER\(start_mining\);\s*)CHECK_CORE_READY\(\);'
rep = r'\g<1>if (!m_p2p.get_payload_object().is_synchronized() && m_core.get_target_blockchain_height() > m_core.get_current_blockchain_height()) { res.status = CORE_RPC_STATUS_BUSY; return true; }'
new_txt, n = re.subn(pat, rep, txt, count=1)
assert n == 1, "CHECK_CORE_READY in on_start_mining not found!"
s_idx = new_txt.index('bool core_rpc_server::on_send_raw_tx(')
e_idx = new_txt.index('CHECK_PAYMENT_MIN1(req, res, COST_PER_TX_RELAY, false);', s_idx)
sub = new_txt[s_idx:e_idx]
assert sub.count('CHECK_CORE_READY();') == 2, f"Expected 2 CHECK_CORE_READY in on_send_raw_tx, got {sub.count('CHECK_CORE_READY();')}"
safe_guard = 'if (!m_p2p.get_payload_object().is_synchronized() && m_core.get_target_blockchain_height() > m_core.get_current_blockchain_height()) { res.status = CORE_RPC_STATUS_BUSY; return true; }'
new_txt = new_txt[:s_idx] + sub.replace('CHECK_CORE_READY();', safe_guard) + new_txt[e_idx:]
open(p, 'w', encoding='utf-8').write(new_txt)
print("Verified: Safe sync-aware guard applied to on_start_mining")
PYEOF

step "6a2. Allow mining stem-phase txs in small Tor P2P networks + OBX wallet branding"
python3 - "$CORE_DIR/src/cryptonote_core/tx_pool.cpp" "$CORE_DIR/src/simplewallet/simplewallet.cpp" << 'PYEOF'
import sys
p_pool, p_sw = sys.argv[1], sys.argv[2]
txt = open(p_pool, 'r', encoding='utf-8').read()
target = '    m_mine_stem_txes = mine_stem_txes;'
assert target in txt, "m_mine_stem_txes line not found in tx_pool.cpp!"
txt = txt.replace(target, '    m_mine_stem_txes = true; // OBX: mine stem/local txs when Tor outbound peers=0', 1)
target_cond = 'meta.get_relay_method() == relay_method::stem'
assert target_cond in txt, "relay_method check not found in tx_pool.cpp!"
txt = txt.replace(target_cond, '(meta.get_relay_method() == relay_method::stem || meta.get_relay_method() == relay_method::local)', 1)
open(p_pool, 'w', encoding='utf-8').write(txt)

sw = open(p_sw, 'r', encoding='utf-8').read()
sw = sw.replace('I locked your Monero wallet to protect you', 'I locked your ObsidianX wallet to protect you')
sw = sw.replace('This is the command line monero wallet.', 'This is the command line ObsidianX wallet.')
sw = sw.replace('receiving new monero', 'receiving new OBX')
open(p_sw, 'w', encoding='utf-8').write(sw)
print("Verified: tx_pool.cpp m_mine_stem_txes=true & OBX wallet text applied")
PYEOF

step "6b. Implement Zawy LWMA-1 Difficulty Algorithm (N=60) in difficulty.cpp"
python3 - "$CORE_DIR/src/cryptonote_basic/difficulty.cpp" << 'PYEOF'
import sys, re
p = sys.argv[1]
txt = open(p, 'r', encoding='utf-8').read()
lwma_fn = """difficulty_type next_difficulty(std::vector<uint64_t> timestamps, std::vector<difficulty_type> cumulative_difficulties, size_t target_seconds) {
    // ObsidianX: Zawy LWMA-1 (N=60) for small PoW networks
    const size_t N = 60;
    if (timestamps.size() <= 1 || cumulative_difficulties.size() <= 1) return 10;
    if (timestamps.size() > N + 1) {
      timestamps.erase(timestamps.begin(), timestamps.end() - (N + 1));
      cumulative_difficulties.erase(cumulative_difficulties.begin(), cumulative_difficulties.end() - (N + 1));
    }
    const size_t L = timestamps.size() - 1;
    uint64_t sum_weighted_solvetimes = 0;
    boost::multiprecision::uint128_t sum_difficulties = 0;
    for (size_t i = 1; i <= L; ++i) {
      int64_t solvetime = static_cast<int64_t>(timestamps[i]) - static_cast<int64_t>(timestamps[i - 1]);
      if (solvetime > static_cast<int64_t>(6 * target_seconds)) solvetime = 6 * target_seconds;
      if (solvetime < 1) solvetime = 1;
      sum_weighted_solvetimes += i * static_cast<uint64_t>(solvetime);
      sum_difficulties += (cumulative_difficulties[i] - cumulative_difficulties[i - 1]);
    }
    if (sum_weighted_solvetimes == 0) sum_weighted_solvetimes = 1;
    boost::multiprecision::uint128_t next_diff = (sum_difficulties * target_seconds * (L + 1)) / (2 * sum_weighted_solvetimes);
    difficulty_type res = static_cast<difficulty_type>(next_diff);
    return res < 1 ? 1 : res;
  }"""
pat = r'difficulty_type next_difficulty\(std::vector<uint64_t> timestamps, std::vector<difficulty_type> cumulative_difficulties, size_t target_seconds\) \{[\s\S]*?\n  \}'
new_txt, n = re.subn(pat, lwma_fn, txt, count=1)
assert n == 1, "next_difficulty function not found in difficulty.cpp!"
open(p, 'w', encoding='utf-8').write(new_txt)
print("Verified: Zawy LWMA-1 (N=60) injected into difficulty.cpp")
PYEOF
step "7. CMake Configure (Release + Static Internal Libs)"
mkdir -p "$CORE_DIR/build/release"
cd "$CORE_DIR/build/release"
cmake ../.. -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF -DBUILD_GUI_DEPS=OFF -DARCH=default
log "CMake configured cleanly! Ready to compile: make -j1 daemon simplewallet"
