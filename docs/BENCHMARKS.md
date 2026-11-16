# ObsidianX (OBX) - Benchmarks de Resiliencia y Recursos

## 1. Recuperacion ante Corte Abrupto (`SIGKILL` / Apagon Simulado)
* **Entorno:** Oracle Cloud VM (`Ubuntu 26.04.1 LTS`, 2 vCPU, 951 MiB RAM física + 5 GiB Swap), contenedor `obsidianx-runtime:22.04`.
* **Nodo probado:** `obsidianxd-peer2` (`--restricted-rpc`, conectado P2P a `obsidianxd-node`).
* **Altura de prueba:** `10` (`top_block_hash`: `8c860f2d99bfdf0a7e0e15f577f86aa30cb16440066844fd32ef16158007e3c9`).
* **Comando ejecutado:** `sudo docker kill -s SIGKILL obsidianxd-peer2 && sudo docker start obsidianxd-peer2`
* **Resultado medido:**
  * Tiempo hasta `Core initialized OK` y respuesta RPC `"status": "OK"`: **`10.67 segundos`**.
  * Integridad LMDB: intacta (misma altura `10` y mismo `top_block_hash`, sin necesidad de `--db-salvage`).
* **Alcance y limites:** Prueba realizada en cadena temprana (`height: 10`). Quedan pendientes benchmarks con cadenas de mayor tamano (>10,000 bloques) y cortes durante rafagas de escritura continua.