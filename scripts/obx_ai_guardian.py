#!/usr/bin/env python3
"""
ObsidianX (OBX) - AI Network & Privacy Guardian v2.0 (Z-Score + Reorg + Forensics)
==================================================================================
1. Anti-Sybil P2P: Evalua subredes /24 y asimetria de trafico (set_bans via RPC).
2. Detector Estadistico (Z-Score): Mide tiempos entre bloques reales y detecta
   anomalias (> 3 sigma) o reorgs inesperados en la cadena.
3. Vigilancia Mempool: Monitorea picos de spam/flooding en get_transaction_pool_stats.
4. Auditoria Forense: Guarda cada alerta/baneo en guardian_alerts.log y metricas
   en vivo en guardian_metrics.json.
"""
import json, math, os, random, statistics, time, urllib.request
from collections import Counter

RPC_BASE = "http://127.0.0.1:38081"
METRICS_FILE = os.path.expanduser("~/obsidianx/runtime/guardian_metrics.json")
ALERTS_LOG = os.path.expanduser("~/obsidianx/runtime/guardian_alerts.log")


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


def log_alert(kind: str, detail: dict):
    entry = {"timestamp": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()), "type": kind, **detail}
    with open(ALERTS_LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")


def analyze_block_timing(height: int):
    if height < 5:
        return 0.0, 0.0, "NORMAL"
    timestamps = []
    for bh in range(max(1, height - 20), height):
        hdr = json_rpc("get_block_header_by_height", {"height": bh}).get("block_header", {})
        ts = int(hdr.get("timestamp", 0))
        if ts > 0:
            timestamps.append(ts)
    if len(timestamps) < 4:
        return 0.0, 0.0, "NORMAL"
    deltas = [max(0, timestamps[i] - timestamps[i - 1]) for i in range(1, len(timestamps))]
    mean_dt = statistics.mean(deltas[:-1]) if len(deltas) > 2 else statistics.mean(deltas)
    stdev_dt = statistics.stdev(deltas[:-1]) if len(deltas) > 2 else 0.0
    latest_dt = deltas[-1]
    z_score = ((latest_dt - mean_dt) / stdev_dt) if stdev_dt > 1.0 else 0.0
    status = "ANOMALY_TIMING" if abs(z_score) > 3.0 else "NORMAL"
    return round(mean_dt, 1), round(z_score, 2), status


def main():
    banned_total = 0
    reorgs_detected = 0
    banned_ips = set()
    last_height = 0
    last_hash_at_height = {}
    cycle = 0
    print("[OBX-AI v2.0] Guardian estadistico y Anti-Sybil iniciado sobre obsidianxd", flush=True)

    while True:
        cycle += 1
        try:
            info = json_rpc("get_info")
            h = int(info.get("height", 1))
            top_hash = str(info.get("top_block_hash", ""))
            conns = json_rpc("get_connections").get("connections", [])
            pool = rest_get("/get_transaction_pool_stats").get("pool_stats", {})

            # 1. Deteccion de Reorg / Bifurcacion
            if h in last_hash_at_height and last_hash_at_height[h] != top_hash:
                reorgs_detected += 1
                log_alert("REORG_DETECTED", {"height": h, "old_hash": last_hash_at_height[h], "new_hash": top_hash})
            elif h < last_height:
                reorgs_detected += 1
                log_alert("CHAIN_ROLLBACK", {"from_height": last_height, "to_height": h})
            last_height = h
            last_hash_at_height[h] = top_hash

            # 2. Scoring Anti-Sybil P2P (/24 + pasividad + estado)
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
                reasons = []
                if subnet_counts[subnet] >= 2:
                    risk += 45; reasons.append("subnet_cluster")
                if live_t > 180 and (recv_c + 1) / (send_c + 1) < 0.05:
                    risk += 35; reasons.append("passive_spy_ratio")
                if state not in ("state_normal", "state_synchronizing") and live_t > 90:
                    risk += 25; reasons.append(f"bad_state:{state}")

                if risk >= 60 and ip not in banned_ips:
                    bans_to_send.append({"host": ip, "ban": True, "seconds": 86400})
                    banned_ips.add(ip)
                    banned_total += 1
                    log_alert("SYBIL_BAN", {"ip": ip, "risk_score": risk, "reasons": reasons})
                    print(f"[OBX-AI-SHIELD] 🚨 Peer {ip} (Riesgo {risk}/100, {reasons}) -> BANEADO 24h", flush=True)

            if bans_to_send:
                json_rpc("set_bans", {"bans": bans_to_send})

            # 3. Detector Z-Score de tiempos entre bloques + Poisson Chaff
            avg_bt, z_bt, timing_status = analyze_block_timing(h)
            if timing_status != "NORMAL":
                log_alert("BLOCK_TIMING_ANOMALY", {"height": h, "avg_s": avg_bt, "z_score": z_bt})

            if h > 1:
                json_rpc("get_block_header_by_height", {"height": random.randint(0, h - 1)})

            # 4. Guardar metricas reales auditables
            mempool_txs = int(pool.get("txs_total", 0))
            if mempool_txs > 200:
                log_alert("MEMPOOL_SPIKE", {"txs_total": mempool_txs, "bytes_total": int(pool.get("bytes_total", 0))})

            metrics = {
                "timestamp": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
                "cycle": cycle,
                "chain_height": h,
                "peers_analyzed": len(conns),
                "mempool_txs": mempool_txs,
                "mempool_bytes": int(pool.get("bytes_total", 0)),
                "avg_block_time_s": avg_bt,
                "timing_z_score": z_bt,
                "anomaly_status": timing_status,
                "reorgs_detected": reorgs_detected,
                "banned_sybil_total": banned_total,
                "status": "ACTIVE",
            }
            save_metrics(metrics)
            if cycle % 5 == 1:
                print(f"[OBX-AI v2] Ciclo #{cycle} | Altura: {h} | Pares: {len(conns)} | T.Bloque: {avg_bt}s (Z={z_bt}) | Baneos: {banned_total}", flush=True)

        except Exception as e:
            print(f"[OBX-AI-WARN] Esperando RPC obsidianxd: {e}", flush=True)

        time.sleep(max(10.0, min(random.expovariate(1.0 / 20.0), 40.0)))


if __name__ == "__main__":
    main()
