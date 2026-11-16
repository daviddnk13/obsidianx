# ObsidianX (OBX) - Benchmarks de Resiliencia y Recursos

## 1. Recuperacion ante Terminacion Abrupta del Proceso (`SIGKILL`)
* **Entorno:** Oracle Cloud VM (`Ubuntu 26.04.1 LTS`, 2 vCPU, 951 MiB RAM fisica + 5 GiB Swap), contenedor `obsidianx-runtime:22.04`.
* **Nodo probado:** `obsidianxd-peer2` (`--restricted-rpc`, conectado P2P a `obsidianxd-node`).
* **Altura de prueba:** `9` (`top_block_hash`: `d137446b62ffe9d17df40a4f82d155c34486a3abbb21ef0ed9229b5236980d58`).
* **Comando ejecutado:** `sudo docker kill -s SIGKILL obsidianxd-peer2 && sudo docker start obsidianxd-peer2`
* **Resultado medido:**
  * Tiempo hasta `Core initialized OK` y respuesta RPC `"status": "OK"`: **`45.19 segundos`**.
  * Integridad LMDB: intacta (misma altura `9` y mismo `top_block_hash`, sin necesidad de `--db-salvage`).
* **Alcance y limites:** Prueba realizada en cadena temprana (`height: 9`). Esta prueba mata el proceso pero conserva la cache de pagina del sistema operativo; quedan pendientes pruebas con reinicio forzado de VM (`systemctl reboot -f`) usando `--db-sync-mode safe:sync` y cadenas >10,000 bloques.