#!/usr/bin/env bash
set -euo pipefail

OBX_DIR="${HOME}/obsidianx-testnet"
RELEASE_URL="${OBX_RELEASE_URL:-https://github.com/daviddnk13/obsidianx/releases/download/v0.1.0-testnet/obsidianx-linux-x86_64.zip}"
SEED_CLEARNET="92.5.87.63:38080"

mkdir -p "${OBX_DIR}/bin" "${OBX_DIR}/data"
echo "=== ObsidianX (OBX) Testnet Setup ==="
if [ ! -x "${OBX_DIR}/bin/obsidianxd" ]; then
  echo "Descargando binarios oficiales..."
  curl -fL "${RELEASE_URL}" -o "${OBX_DIR}/obsidianx-linux-x86_64.zip"
  unzip -o "${OBX_DIR}/obsidianx-linux-x86_64.zip" -d "${OBX_DIR}/bin"
  chmod +x "${OBX_DIR}/bin/"*
fi

if ! docker ps --format '{{.Names}}' | grep -q '^obsidianx-testnet-node$'; then
  echo "Iniciando nodo local conectado a ${SEED_CLEARNET}..."
  docker run -d --name obsidianx-testnet-node --restart unless-stopped \
    --network=host \
    -v "${OBX_DIR}/bin:/usr/local/bin:ro" \
    -v "${OBX_DIR}/data:/data" \
    ubuntu:22.04 \
    /usr/local/bin/obsidianxd \
      --data-dir /data \
      --p2p-bind-ip 0.0.0.0 --p2p-bind-port 38080 \
      --rpc-bind-ip 127.0.0.1 --rpc-bind-port 38081 \
      --add-priority-node "${SEED_CLEARNET}" \
      --non-interactive
fi

echo "Nodo activo. Para abrir o crear tu billetera ejecuta:"
echo "docker run -it --rm --network=host -v ${OBX_DIR}/bin:/usr/local/bin:ro -v ${OBX_DIR}:/work ubuntu:22.04 /usr/local/bin/obsidianx-wallet-cli --daemon-address 127.0.0.1:38081 --generate-new-wallet /work/mi_wallet_obx"