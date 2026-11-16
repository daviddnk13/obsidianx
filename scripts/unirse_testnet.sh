#!/usr/bin/env bash
set -euo pipefail

for cmd in curl unzip docker; do
  command -v "$cmd" >/dev/null || { echo "Error: falta $cmd instalado."; exit 1; }
done

OBX_DIR="${HOME}/obsidianx-testnet"
OBX_NET_VER="v0.2.5-testnet"
BASE_URL="${OBX_RELEASE_BASE:-https://github.com/daviddnk13/obsidianx/releases/download/${OBX_NET_VER}}"
SEED_CLEARNET="92.5.87.63:38080"

mkdir -p "${OBX_DIR}/bin" "${OBX_DIR}/data"
echo "=== ObsidianX (OBX) Testnet Setup (${OBX_NET_VER}) ==="

OLD_VER=$(cat "${OBX_DIR}/.net_version" 2>/dev/null || echo "")
if [ "$OLD_VER" != "$OBX_NET_VER" ] || [ ! -x "${OBX_DIR}/bin/obsidianxd" ]; then
  echo "Actualizando binarios y reiniciando cadena de Testnet (${OBX_NET_VER})..."
  docker rm -f obsidianx-testnet-node 2>/dev/null || true
  rm -rf "${OBX_DIR}/data/"*
  curl -fL "${BASE_URL}/obsidianx-linux-x86_64.zip" -o "${OBX_DIR}/obsidianx-linux-x86_64.zip"
  unzip -o "${OBX_DIR}/obsidianx-linux-x86_64.zip" -d "${OBX_DIR}/bin"
  (cd "${OBX_DIR}/bin" && sed -i 's|bin/||g' SHA256SUMS-linux.txt && sha256sum -c SHA256SUMS-linux.txt)
  chmod +x "${OBX_DIR}/bin/obsidianxd" "${OBX_DIR}/bin/obsidianx-wallet-cli" "${OBX_DIR}/bin/obsidianx-wallet-rpc"
  echo "$OBX_NET_VER" > "${OBX_DIR}/.net_version"
fi

if ! docker image inspect obsidianx-runtime:22.04 >/dev/null 2>&1; then
  echo "Construyendo imagen runtime Ubuntu 22.04..."
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
  echo "Iniciando nodo Testnet conectado a ${SEED_CLEARNET}..."
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
      --fast-block-sync 0 \
      --disable-dns-checkpoints \
      --check-updates disabled \
      --non-interactive
fi

echo "Nodo activo. Para abrir o crear tu billetera ejecuta:"
echo "docker run -it --rm --network=host -v ${OBX_DIR}/bin:/usr/local/bin:ro -v ${OBX_DIR}:/work obsidianx-runtime:22.04 /usr/local/bin/obsidianx-wallet-cli --daemon-address 127.0.0.1:38081 --generate-new-wallet /work/mi_wallet_obx"