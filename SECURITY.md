# Política de Seguridad — ObsidianX (OBX)

## Protección de Llaves y Semillas
- **Nunca subas a Git** archivos con llaves privadas o semillas (`mi_billetera_genesis.json`, `*.keys`, `*.wallet`, `*.seed`, `*.enc`).
- En Windows, cifra siempre tu billetera local usando:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\scripts\cifrar_billetera.ps1 -Accion cifrar
  ```
- Guarda tu frase mnemónica de 25 palabras **únicamente en papel** fuera de línea.

## Reporte de Vulnerabilidades
Si encuentras un fallo en `scripts/07_apply_all_params.sh`, `scripts/obx_ai_guardian.py` o en la configuración de red Tor/RPC, abre un *Security Advisory* privado en GitHub antes de divulgarlo públicamente.
