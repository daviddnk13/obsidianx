#!/usr/bin/env bash
set -euo pipefail

OBX_DIR="${HOME}/obsidianx-testnet"
BASE_URL="${OBX_RELEASE_BASE:-https://github.com/daviddnk13/obsidianx/releases/latest/download}"
SEED_CLEARNET="92.5.87.63:38080"

for cmd in curl unzip docker; do command -v $cmd >/dev/null || { echo "Falta $cmd"; exit 1; }; done
mkdir -p "${OBX_DIR}/bin" "${OBX_DIR}/data"
echo "=== ObsidianX (OBX) Testnet Setup ==="

if [ ! -x "${OBX_DIR}/bin/obsidianxd" ]; then
  echo "Descargando binarios oficiales y SHA256SUMS..."
  curl -fL "${BASE_URL}/obsidianx-linux-x86_64.zip" -o "${OBX_DIR}/obsidianx-linux-x86_64.zip"
  unzip -o "${OBX_DIR}/obsidianx-linux-x86_64.zip" -d "${OBX_DIR}/bin"
  (cd "${OBX_DIR}/bin" && sed -i 's|bin/||g' SHA256SUMS-linux.txt && sha256sum -c SHA256SUMS-linux.txt)
  chmod +x "${OBX_DIR}/bin/obsidianxd" "${OBX_DIR}/bin/obsidianx-wallet-cli" "${OBX_DIR}/bin/obsidianx-wallet-rpc"
fi

if ! docker image inspect obsidianx-runtime:22.04 >/dev/null 2>&1; then
  echo "Construyendo imagen runtime Ubuntu 22.04 con librerias compartidas..."
  docker build -t obsidianx-runtime:22.04 - << 'DOCKEREOF'
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libboost-program-options1.74.0 libboost-filesystem1.74.0 \
    libboost-thread1.74.0 libboost-serialization1.74.0 libboost-chrono1.74.0 \
    libboost-regex1.74.0 libssl3 libzmq5 libunbound8 libsodium23 \
    libreadline8 libldns3 libexpat1 libunwind8 liblzma5 \
    && rm -rf /var/lib/apt/lists/*
DOCKEREOF
fi

if ! docker ps --format '{{.Names}}' | grep -q '^obsidianx-testnet-node$'; then
  echo "Iniciando nodo local conectado a ${SEED_CLEARNET}..."
  docker run -d --name obsidianx-testnet-node --restart unless-stopped \
    --network=host \
    -v "${OBX_DIR}/bin:/usr/local/bin:ro" \
    -v "${OBX_DIR}/data:/data" \
    obsidianx-runtime:22.04 \
    /usr/local/bin/obsidianxd \
      --data-dir /data \
      --p2p-bind-ip 0.0.0.0 --p2p-bind-port 38080 \
      --rpc-bind-ip 127.0.0.1 --rpc-bind-port 38081 \
      --add-priority-node "${SEED_CLEARNET}" \
      --disable-dns-checkpoints \
      --check-updates disabled \
      --non-interactive
fi

echo "Nodo activo. Para abrir o crear tu billetera ejecuta:"
echo "docker run -it --rm --network=host -v ${OBX_DIR}/bin:/usr/local/bin:ro -v ${OBX_DIR}:/work obsidianx-runtime:22.04 /usr/local/bin/obsidianx-wallet-cli --daemon-address 127.0.0.1:38081 --generate-new-wallet /work/mi_wallet_obx"