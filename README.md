# ObsidianX (OBX) — Privacidad Total, IA P2P y Resiliencia Anti-Apagones

[![Cloud Node 24/7](https://github.com/daviddnk13/obsidianx/actions/workflows/obsidianx_24_7_cloud_node.yml/badge.svg)](https://github.com/daviddnk13/obsidianx/actions/workflows/obsidianx_24_7_cloud_node.yml)
[![Build ObsidianX](https://github.com/daviddnk13/obsidianx/actions/workflows/build_obsidianx.yml/badge.svg)](https://github.com/daviddnk13/obsidianx/actions/workflows/build_obsidianx.yml)

**ObsidianX (`OBX`)** es una criptomoneda de código abierto basada en **Monero (`v0.18.3.3`)**, diseñada para operar con privacidad de red reforzada, consumo mínimo de recursos y resistencia real frente a cortes eléctricos e internet inestable, sin depender de servidores centrales ni VPS pagados.

- **Portal Web y Explorador en Vivo:** `https://daviddnk13.github.io/obsidianx/` *(activar en Settings -> Pages -> Branch `main` / `/docs`)*
- **Estado de la Red en Vivo:** [PUBLIC_NETWORK_STATUS.md](./PUBLIC_NETWORK_STATUS.md)

---

## ¿Qué hace diferente a ObsidianX?

1. **Agente de IA Guardián P2P (`scripts/obx_ai_guardian.py` v2.0)**
   - **Escudo Anti-Sybil y Caza de Supernodos:** Analiza entropía de subredes `/24` y proporción de paquetes enviados/recibidos para banear automáticamente nodos espía vía RPC (`set_bans`).
   - **Enrutamiento *Patient Dandelion* + *Chaff* Exponencial:** Retiene y retrasa la difusión con distribución exponencial para romper la correlación temporal de tráfico.
   - **Auditor Estadístico de Señuelos:** Evalúa la dispersión log-gamma de las edades de *outputs* en los anillos.
2. **Privacidad de Red con Tor (`.onion`)**
   - Soporte nativo para `--tx-proxy tor,127.0.0.1:9050` y puerto anónimo dedicado **`28084`** (`--anonymous-inbound`), ocultando la IP del operador sin abrir puertos en el router.
3. **Arquitectura Anti-Apagones (Blackout-Proof)**
   - Escritura síncrona segura (`--db-sync-mode safe:sync` + `os.sync()`), modo podado (`--prune-blockchain`) para ahorrar ~2/3 de almacenamiento y **`DIFFICULTY_WINDOW = 60`** bloques para que la red se adapte rápido ante caídas regionales de electricidad.

---

## Política Monetaria Transparente

| Parámetro | Valor | Detalle |
| :--- | :--- | :--- |
| **Ticker / Red** | `OBX` / `obsidianx` | Puertos `28080` (P2P), `28081` (RPC), `28084` (Tor) |
| **Suministro Referencial** | `18,400,000 OBX` | Emisión con *tail emission* mínima de `0.001 OBX` |
| **Recompensa Inicial** | `20 OBX` / bloque | Reducción del 10% cada `100,000` bloques |
| **Fondo Nodos Pioneros (5%)** | `920,000 OBX` | Destinado a recompensas para los primeros 50 operadores de nodo y liquidez comunitaria |

---

## Inicio Rápido (Windows, Linux y Android Termux)

### En Windows (Sin instalar dependencias)
1. Descarga el repositorio y haz doble clic en **`DOBLE_CLIC_INICIAR.bat`**.
2. Presiona **`1`** para generar tu billetera y luego cifra tus llaves con:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\cifrar_billetera.ps1 -Accion cifrar
   ```
3. Presiona **`2`** para iniciar los nodos y el Agente IA Guardián.

### En Linux / Android (Termux 64-bit `aarch64`)
```bash
chmod +x INICIAR_AQUI.sh scripts/*.sh scripts/*.py
bash scripts/09_setup_tor_bridge.sh
bash scripts/08_launch_3_nodes.sh android
```

### Compilación Verificable en la Nube
Cualquier usuario puede auditar los parches en `scripts/07_apply_all_params.sh` y verificar los binarios compilados directamente desde la pestaña **Actions -> Build ObsidianX**.

---

## Programa "Los 50 Nodos Pioneros"
Si levantas un nodo en tu PC, servidor o teléfono Android con Termux y compartes tu dirección `OBX4...` junto con una captura de tu nodo activo en la comunidad oficial, puedes optar a la recompensa inicial del **Fondo de Nodos Pioneros**.
