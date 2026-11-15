<div align="center">

<img src="assets/obsidianx-logo.jpg" alt="ObsidianX Logo" width="180" />

# ObsidianX (OBX) — Testnet C++ (Fork de Monero v0.18)

**Estado actual: Testnet / Alpha Activa en Desarrollo**

</div>

---

## Qué es este proyecto (Transparencia Técnica)

**ObsidianX (`OBX`)** es un fork experimental de **Monero (`release-v0.18`)** en C++ enfocado en la privacidad (RingCT, CLSAG, Bulletproofs+ y RandomX desde el bloque 1) con parámetros ajustados para redes pequeñas y entornos con cortes frecuentes de electricidad.

> **Nota importante:** Este repositorio contiene únicamente el código de parcheo C++ sobre Monero, el flujo de compilación en Ubuntu 22.04 y un explorador web de solo lectura conectado al RPC real de `obsidianxd`. No hay tokens pre-minados ocultos ni simuladores.

---

## Parámetros Verificados del Núcleo C++ (`scripts/07_apply_all_params.sh`)

| Parámetro | Valor en Código | Detalle |
| :--- | :--- | :--- |
| **Base Criptográfica** | `Monero release-v0.18` | RingCT + CLSAG + Bulletproofs+ + RandomX (activados desde altura `1`) |
| **Lanzamiento** | **Fair Launch (0% Premine)** | Sin fondos reservados ni pre-minado |
| **Emisión y Tope** | `21,000,000 OBX` + Tail `0.6 OBX` | Curva suave basada en suministro restante (`>> 20`), suelo de `0.6 OBX/bloque` |
| **Dificultad PoW** | `WINDOW = 120`, `CUT = 15` | Ajuste rápido válido (`window > 2 * cut`) para redes pequeñas |
| **Puertos Soberanos** | `38080` (P2P) / `38081` (RPC) / `38082` (ZMQ) | Puertos propios aislados de Monero Mainnet (`18080`) y Testnet (`28080`) |
| **Prefijos Base58** | `0x1e2c` / `0x1e2d` / `0x1e2e` | Direcciones distintas de Monero para evitar reutilización accidental de llaves |
| **Licencia** | `BSD-3-Clause` | Archivo [`LICENSE`](LICENSE) conservando los avisos originales de Monero |

---

## Cómo Compilar y Probar la Testnet Real

```bash
git clone https://github.com/daviddnk13/obsidianx.git
cd obsidianx
chmod +x scripts/07_apply_all_params.sh
./scripts/07_apply_all_params.sh
cd ~/obsidianx/core-chain/build/release
make -j$(nproc) daemon simplewallet
```

### Ejecutar el Nodo (`obsidianxd`) y la Billetera (`obsidianx-wallet-cli`)
```bash
./bin/monerod --data-dir ~/obx-data --p2p-bind-port 38080 --rpc-bind-port 38081
./bin/monero-wallet-cli --daemon-address 127.0.0.1:38081 --generate-new-wallet ~/mi_billetera_obx
```

### Explorador Web de Solo Lectura
El script `scripts/obx_real_explorer.py` consulta únicamente `get_info` y `get_block_header_by_height` del daemon `obsidianxd` en `127.0.0.1:38081`.

---
## Testnet Publica en Vivo
- **Nodo Semilla (Seed Node)**: 92.5.87.63:38080
- **Explorador RPC Real**: https://obsidianx-obx.duckdns.org
- **Conectar nodo**: ./obsidianxd --p2p-bind-port 38080 --rpc-bind-port 38081 --add-priority-node 92.5.87.63:38080

- **Nodo Oculto Tor (.onion)**: 3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38083
- **Conectar por Tor**: ./obsidianxd --p2p-bind-port 38080 --rpc-bind-port 38081 --tx-proxy tor,127.0.0.1:9050,16 --add-priority-node 3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38083

## Unirse a la Testnet en 1 Comando (Linux + Docker)

    curl -sSL [https://raw.githubusercontent.com/daviddnk13/obsidianx/main/scripts/unirse_testnet.sh](https://raw.githubusercontent.com/daviddnk13/obsidianx/main/scripts/unirse_testnet.sh) | bash

* Explorador HTTPS: [https://obsidianx-obx.duckdns.org](https://obsidianx-obx.duckdns.org)
* Clearnet Seed: 92.5.87.63:38080
* Tor Hidden Service: 3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38083
* Comunidad Telegram: [https://t.me/ObsidianX_OBX](https://t.me/ObsidianX_OBX)
