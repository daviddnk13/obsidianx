#!/usr/bin/env python3
import hashlib
import json
import os
import time
import uuid
from datetime import datetime, timezone

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NODES_DIR = os.path.join(BASE_DIR, "network-nodes")
CHAIN_FILES = [
    os.path.join(NODES_DIR, "node1", "blockchain.json"),
    os.path.join(NODES_DIR, "node2", "blockchain.json"),
    os.path.join(NODES_DIR, "node3", "blockchain.json"),
]
STATUS_MD = os.path.join(BASE_DIR, "PUBLIC_NETWORK_STATUS.md")


def sha256_hex(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def get_block_reward(height: int) -> float:
    if height == 0:
        return 20.0
    if height == 1:
        return 920000.0
    intervals = height // 100000
    reward = 20.0 * (0.9 ** intervals)
    return round(max(0.001, reward), 6)


def load_or_init_chain():
    for cf in CHAIN_FILES:
        if os.path.exists(cf):
            try:
                with open(cf, "r", encoding="utf-8-sig") as f:
                    data = json.load(f)
                if isinstance(data, list) and len(data) > 0:
                    return data
            except Exception:
                pass
    now = int(time.time())
    gen_hash = sha256_hex("ObsidianX - Privacy is not a crime - 2024")
    b0 = {
        "height": 0,
        "hash": gen_hash,
        "prev_hash": "0" * 64,
        "timestamp": now,
        "reward_obx": 20.0,
        "difficulty": 1,
        "message": "ObsidianX - Privacy is not a crime - 2024",
    }
    b1 = {
        "height": 1,
        "hash": sha256_hex(f"{gen_hash}:1:DEV_FUND_OBX"),
        "prev_hash": gen_hash,
        "timestamp": now,
        "reward_obx": 920000.0,
        "difficulty": 1,
        "message": "Fondo de Nodos Pioneros y Liquidez OBX (920,000 OBX)",
    }
    return [b0, b1]


def sync_nodes(chain):
    payload = json.dumps(chain, indent=2, ensure_ascii=False)
    for cf in CHAIN_FILES:
        os.makedirs(os.path.dirname(cf), exist_ok=True)
        with open(cf, "w", encoding="utf-8") as f:
            f.write(payload)
            f.flush()
            os.fsync(f.fileno())


def main():
    chain = load_or_init_chain()
    last = chain[-1]
    new_h = int(last["height"]) + 1
    nonce = uuid.uuid4().hex
    new_hash = sha256_hex(f"{last['hash']}:{new_h}:{nonce}")
    diff = min(60, max(1, (new_h // 2) + 1))
    rew = get_block_reward(new_h)
    now_ts = int(time.time())

    chain.append({
        "height": new_h,
        "hash": new_hash,
        "prev_hash": last["hash"],
        "timestamp": now_ts,
        "reward_obx": rew,
        "difficulty": diff,
        "message": "Mined by ObsidianX Cloud Node 24/7 (GitHub Actions)",
    })
    sync_nodes(chain)

    total_obx = sum(float(b.get("reward_obx", 0.0)) for b in chain)
    utc_now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    status_content = f"""# ObsidianX (OBX) — Estado Público de la Red 24/7

- **Estado del Nodo Nube (GitHub Actions):** ACTIVO
- **Última sincronización:** {utc_now}
- **Altura de la cadena:** {len(chain)} bloques (Último bloque: `#{new_h}`)
- **Dificultad actual:** {diff}
- **Suministro emitido:** {total_obx:,.2f} OBX
- **Último Hash:** `{new_hash}`
"""
    with open(STATUS_MD, "w", encoding="utf-8") as f:
        f.write(status_content)

    print(f"[OBX-CLOUD] Bloque #{new_h} validado. Suministro total: {total_obx:,.2f} OBX")


if __name__ == "__main__":
    main()
