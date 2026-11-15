# ObsidianX (OBX) - Testnet & Mainnet Launch Policy

## 1. Current Network: Disposable Public Testnet (`v0.2.0-testnet`)
* All coins mined on the current Testnet have **zero commercial value** and exist strictly for testing RingCT/CLSAG transactions, LWMA-1 difficulty, Tor P2P, and RPC tooling.
* **Testnet chains will be reset** before Mainnet launch.

## 2. Fair-Launch Mainnet Criteria
Before any Mainnet genesis block is announced:
1. External review of the exact consensus diff (`scripts/07_apply_all_params.sh` against Monero `v0.18.5.4`).
2. At least 5-10 independent community seed/full nodes ready to join.
3. Fresh Mainnet `GENESIS_TX`, `GENESIS_NONCE`, `NETWORK_ID`, and public launch timestamp published in advance so everyone starts at height 0 simultaneously (0% premine).