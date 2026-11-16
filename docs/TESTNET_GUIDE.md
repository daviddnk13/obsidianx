# ObsidianX (OBX) — Public Testnet Guide (EN / ES)

## Verified Consensus & Network Specs
* **Codebase:** Real C++ CryptoNote fork (`Monero release-v0.18` / `v0.18.5.4-release`)
* **Launch:** Fair Launch, **0% premine**
* **PoW & Difficulty:** RandomX, Zawy **LWMA-1 (N=60)**, 120s block target
* **Privacy:** RingCT + CLSAG + Bulletproofs+ (v16 active from Block 1)
* **Emission:** 18M OBX base emission + 0.6 OBX/block perpetual tail emission (no hard cap)
* **Ports:** P2P `38080` | RPC `38081` (localhost only) | ZMQ `38082`
* **Live Explorer & AI Guardian:** https://obsidianx-obx.duckdns.org
* **Clearnet P2P Seed:** `92.5.87.63:38080`
* **Tor P2P Seed:** `3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38083`
* **Tor Remote Wallet (Restricted RPC):** `3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38081`

## 1. Quick Join (Linux + Docker)

    curl -sSL https://raw.githubusercontent.com/daviddnk13/obsidianx/main/scripts/unirse_testnet.sh | bash

## 2. Connect Wallet via Tor Remote Node (No Full Sync Needed)

    obsidianx-wallet-cli --proxy 127.0.0.1:9050 --daemon-address 3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38081 --generate-new-wallet mi_wallet_obx

## 3. Solo Mining on Your Node

    curl -s -X POST http://127.0.0.1:38081/start_mining -d '{"miner_address":"YOUR_V_ADDRESS","threads_count":2,"do_background_mining":false,"ignore_battery":true}' -H 'Content-Type: application/json'

## 4. Verify Downloads

Always verify downloaded archives against the published `SHA256SUMS` file in GitHub Releases:

    sha256sum -c SHA256SUMS-linux.txt

---
Community & Support: https://t.me/ObsidianX_OBX

## 5. Windows Users (via WSL2 + Docker)
1. Install WSL2 Ubuntu (`wsl --install`) and Docker Desktop with WSL2 backend enabled.
2. Inside the Ubuntu WSL2 terminal, run the 1-command Linux setup:

    curl -sSL https://raw.githubusercontent.com/daviddnk13/obsidianx/main/scripts/unirse_testnet.sh | bash
