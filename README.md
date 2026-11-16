<div align="center">

<img src="assets/obsidianx-logo.jpg" alt="ObsidianX Logo" width="180" />

# ObsidianX (OBX) - Testnet C++ (Fork de Monero v0.18.5.4)

**Estado actual: Testnet Publica Descartable (`v0.2.4-testnet`) - Las monedas de prueba no tienen valor comercial.**

</div>

## Que es este proyecto (Transparencia Tecnica)

**ObsidianX (`OBX`)** es un fork experimental en C++ de **Monero (`v0.18.5.4`)** enfocado en privacidad (RingCT, CLSAG, Bulletproofs+ y RandomX desde el bloque 1), con ajuste de dificultad **LWMA-1** y soporte **Tor (.onion)** para redes pequenas y conexiones inestables.

* Consulta la politica completa de pruebas y criterios de futura Mainnet en [`docs/LAUNCH_POLICY.md`](docs/LAUNCH_POLICY.md).
* El lanzamiento justo (0% premine, genesis definitivo, hora anunciada y 5-10 nodos independientes) aplicara exclusivamente a la futura Mainnet tras revision externa del diff.

## Parametros Verificados del Nucleo C++ (`scripts/07_apply_all_params.sh`)

| Parametro | Valor en Codigo | Detalle |
| :--- | :--- | :--- |
| **Base Criptografica** | `Monero v0.18.5.4` | Tag oficial fijado; RingCT + CLSAG + Bulletproofs+ + RandomX desde altura `1` |
| **Emision** | `18,000,000 OBX` base + `0.6 OBX` tail | Curva suave (`>> 20`), ~17.17 OBX en bloque 1, cola perpetua (sin tope duro). Bloque 0 con 17.5922 OBX en salida no gastable |
| **Dificultad PoW** | `Zawy LWMA-1 (N = 60)` | Target `120s`, dificultad inicial `10` para arranque de Testnet |
| **Puertos Soberanos** | `38080` (P2P) / `38081` (RPC) / `38082` (ZMQ) | Aislados de Monero Mainnet (`18080`) y Testnet (`28080`) |
| **Prefijos Base58** | `0x1e2c` / `0x1e2d` / `0x1e2e` | Direcciones propias con prefijo `Vo...` (97 caracteres) |
| **Licencia** | `BSD-3-Clause` | Archivo [`LICENSE`](LICENSE) con avisos de CryptoNote y The Monero Project |

## Unirse a la Testnet en 1 Comando (Linux + Docker)

    curl -sSL https://raw.githubusercontent.com/daviddnk13/obsidianx/main/scripts/unirse_testnet.sh | bash

*(El script verifica `SHA256SUMS-linux.txt`, construye la imagen runtime `ubuntu:22.04` con las librerias compartidas, desactiva checkpoints/updates DNS de Monero y conecta al seed de Testnet).*

## Compilar desde Fuente y Probar Manualmente

    git clone https://github.com/daviddnk13/obsidianx.git
    cd obsidianx
    chmod +x scripts/07_apply_all_params.sh
    ./scripts/07_apply_all_params.sh
    cd ~/obsidianx/core-chain/build/release
    make -j$(nproc) daemon simplewallet wallet_rpc_server

### Ejecutar Nodo (`obsidianxd`) y Billetera (`obsidianx-wallet-cli`)

    ./bin/obsidianxd --data-dir ~/obx-data --p2p-bind-port 38080 --rpc-bind-port 38081 --disable-dns-checkpoints --check-updates disabled --add-priority-node 92.5.87.63:38080
    ./bin/obsidianx-wallet-cli --daemon-address 127.0.0.1:38081 --generate-new-wallet ~/mi_billetera_obx

### Conectar Billetera por Tor (Nodo Remoto Restricted RPC)

    ./bin/obsidianx-wallet-cli --proxy 127.0.0.1:9050 --daemon-address 3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38081 --generate-new-wallet ~/mi_billetera_obx

## Infraestructura Testnet Publica
* **Explorador HTTPS & Monitor Heuristico:** https://obsidianx-obx.duckdns.org
* **Clearnet P2P Seed:** `92.5.87.63:38080`
* **Tor P2P Seed:** `3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38083`
* **Tor Wallet Remote Node (`--restricted-rpc`):** `3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38081`
* **Guia Completa:** [`docs/TESTNET_GUIDE.md`](docs/TESTNET_GUIDE.md)
* **Comunidad Telegram:** https://t.me/ObsidianX_OBX