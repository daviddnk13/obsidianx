#!/usr/bin/env python3
"""
ObsidianX (OBX) - AI Network & Privacy Guardian (Conectado al RPC C++ real)
===========================================================================
Audita conexiones P2P reales (get_connections), aplica baneos Anti-Sybil
(set_bans), monitorea spam en mempool (get_transaction_pool_stats) y ejecuta
consultas de ofuscación temporal (Poisson) contra obsidianxd (127.0.0.1:38081).
"""
import json, os, random, time, urllib.request
from collections import Counter

RPC_BASE = "http://127.0.0.1:38081"
METRICS_FILE = os.path.expanduser("~/obsidianx/runtime/guardian_metrics.json")


def json_rpc(method: str, params: dict = None):
    payload = json.dumps({"jsonrpc": "2.0", "id": "obx-ai", "method": method, "params": params or {}}).encode("utf-8")
    req = urllib.request.Request(f"{RPC_BASE}/json_rpc", data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.loads(r.read().decode("utf-8")).get("result", {})


def rest_get(path: str):
    with urllib.request.urlopen(f"{RPC_BASE}{path}", timeout=5) as r:
        return json.loads(r.read().decode("utf-8"))


def save_metrics(data: dict):
    tmp = METRICS_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, METRICS_FILE)


def main():
    banned_total = 0
    banned_ips = set()
    cycle = 0
    print("[OBX-AI] Guardian P2P & Privacidad iniciado sobre obsidianxd (127.0.0.1:38081)", flush=True)

    while True:
        cycle += 1
        try:
            info = json_rpc("get_info")
            conns_res = json_rpc("get_connections")
            conns = conns_res.get("connections", [])
            pool = rest_get("/get_transaction_pool_stats").get("pool_stats", {})

            # 1. Análisis de entropía /24 y comportamiento P2P
            subnets = [".".join(c.get("ip", "").split(".")[:3]) for c in conns if "." in c.get("ip", "") and not c.get("ip", "").startswith("127.")]
            subnet_counts = Counter(subnets)

            bans_to_send = []
            for c in conns:
                ip = c.get("ip", "")
                if not ip or ip.startswith("127.") or ip.endswith(".onion"):
                    continue
                subnet = ".".join(ip.split(".")[:3]) if "." in ip else ip
                recv_c = int(c.get("recv_count", 0))
                send_c = int(c.get("send_count", 0))
                live_t = max(int(c.get("live_time", 1)), 1)
                state = c.get("state", "")

                risk = 0
                if subnet_counts[subnet] >= 2:
                    risk += 45
                if live_t > 180 and (recv_c + 1) / (send_c + 1) < 0.05:
                    risk += 35
                if state not in ("state_normal", "state_synchronizing") and live_t > 90:
                    risk += 25

                if risk >= 60 and ip not in banned_ips:
                    bans_to_send.append({"host": ip, "ban": True, "seconds": 86400})
                    banned_ips.add(ip)
                    banned_total += 1
                    print(f"[OBX-AI-SHIELD] 🚨 Peer sospechoso {ip} (Riesgo {risk}/100) -> BANEADO 24h", flush=True)

            if bans_to_send:
                json_rpc("set_bans", {"bans": bans_to_send})

            # 2. Chaff de lectura real (Poisson) sobre la altura actual
            h = int(info.get("height", 1))
            if h > 1:
                json_rpc("get_block_header_by_height", {"height": random.randint(0, h - 1)})

            # 3. Guardar métricas reales auditables
            metrics = {
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
                "cycle": cycle,
                "chain_height": h,
                "peers_analyzed": len(conns),
                "mempool_txs": int(pool.get("txs_total", 0)),
                "mempool_bytes": int(pool.get("bytes_total", 0)),
                "banned_sybil_total": banned_total,
                "status": "ACTIVE",
            }
            save_metrics(metrics)
            if cycle % 5 == 1:
                print(f"[OBX-AI] Ciclo #{cycle} | Altura: {h} | Pares auditados: {len(conns)} | Mempool: {metrics['mempool_txs']} txs | Baneos: {banned_total}", flush=True)

        except Exception as e:
            print(f"[OBX-AI-WARN] Esperando RPC obsidianxd: {e}", flush=True)

        sleep_s = max(10.0, min(random.expovariate(1.0 / 20.0), 40.0))
        time.sleep(sleep_s)


if __name__ == "__main__":
    main()
