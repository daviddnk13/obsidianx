#!/usr/bin/env python3
"""
ObsidianX (OBX) - Heuristic Network Monitor v2.1 (Dry-Run Safe + Reorg + Forensics)
====================================================================================
1. Anti-Sybil P2P (Dry-Run by default): Flags /24 clusters and asymmetric peers.
   Set OBX_GUARDIAN_DRY_RUN=0 only when active set_bans enforcement is desired.
2. Rolling Block-Time Monitor: Compares 20-block moving average against 120s target.
3. Mempool & Reorg Forensics: Logs spikes and rollbacks to guardian_alerts.log.
"""
import json
import os
import statistics
import time
import urllib.request
from collections import Counter

RPC_BASE = "http://127.0.0.1:38081"
RUNTIME_DIR = os.path.expanduser("~/obsidianx/runtime")
METRICS_FILE = os.path.join(RUNTIME_DIR, "guardian_metrics.json")
ALERTS_LOG = os.path.join(RUNTIME_DIR, "guardian_alerts.log")
DRY_RUN = os.environ.get("OBX_GUARDIAN_DRY_RUN", "1") == "1"
WHITELIST_IPS = set(filter(None, os.environ.get("OBX_GUARDIAN_WHITELIST", "127.0.0.1,92.5.87.63").split(",")))


def json_rpc(method: str, params: dict = None):
    payload = json.dumps({"jsonrpc": "2.0", "id": "obx-mon", "method": method, "params": params or {}}).encode("utf-8")
    req = urllib.request.Request(f"{RPC_BASE}/json_rpc", data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.loads(r.read().decode("utf-8")).get("result", {})


def rest_get(path: str):
    with urllib.request.urlopen(f"{RPC_BASE}{path}", timeout=5) as r:
        return json.loads(r.read().decode("utf-8"))


def save_metrics(data: dict):
    os.makedirs(RUNTIME_DIR, exist_ok=True)
    tmp = METRICS_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    os.replace(tmp, METRICS_FILE)


def log_alert(kind: str, detail: dict):
    os.makedirs(RUNTIME_DIR, exist_ok=True)
    entry = {"timestamp": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()), "type": kind, **detail}
    with open(ALERTS_LOG, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry) + "\n")


def analyze_block_timing(height: int):
    if height < 6:
        return 0.0, 0.0, "NORMAL"
    timestamps = []
    for bh in range(max(1, height - 20), height):
        hdr = json_rpc("get_block_header_by_height", {"height": bh}).get("block_header", {})
        ts = int(hdr.get("timestamp", 0))
        if ts > 0:
            timestamps.append(ts)
    if len(timestamps) < 5:
        return 0.0, 0.0, "NORMAL"
    deltas = [max(0, timestamps[i] - timestamps[i - 1]) for i in range(1, len(timestamps))]
    mean_dt = statistics.mean(deltas)
    # Relative drift vs 120s PoW target over the rolling window
    drift = (mean_dt - 120.0) / 120.0
    status = "ANOMALY_TIMING" if (mean_dt < 25.0 or mean_dt > 600.0) else "NORMAL"
    return round(mean_dt, 1), round(drift, 2), status


def main():
    os.makedirs(RUNTIME_DIR, exist_ok=True)
    banned_total = 0
    reorgs_detected = 0
    flagged_ips = set()
    last_height = 0
    last_hash_at_height = {}
    cycle = 0
    print(f"[OBX-Monitor v2.1] Iniciado (dry_run={DRY_RUN})", flush=True)

    while True:
        cycle += 1
        try:
            info = json_rpc("get_info")
            h = int(info.get("height", 1))
            top_hash = str(info.get("top_block_hash", ""))
            conns = json_rpc("get_connections").get("connections", [])
            pool = rest_get("/get_transaction_pool_stats").get("pool_stats", {})

            if h in last_hash_at_height and last_hash_at_height[h] != top_hash:
                reorgs_detected += 1
                log_alert("REORG_DETECTED", {"height": h, "old_hash": last_hash_at_height[h], "new_hash": top_hash})
            elif h < last_height:
                reorgs_detected += 1
                log_alert("CHAIN_ROLLBACK", {"from_height": last_height, "to_height": h})
            last_height = h
            last_hash_at_height[h] = top_hash

            subnets = [".".join(c.get("ip", "").split(".")[:3]) for c in conns if "." in c.get("ip", "") and not c.get("ip", "").startswith("127.")]
            subnet_counts = Counter(subnets)
            bans_to_send = []
            for c in conns:
                ip = c.get("ip", "")
                if not ip or ip in WHITELIST_IPS or ip.startswith("127.") or ip.endswith(".onion"):
                    continue
                subnet = ".".join(ip.split(".")[:3]) if "." in ip else ip
                recv_c = int(c.get("recv_count", 0))
                send_c = int(c.get("send_count", 0))
                live_t = max(int(c.get("live_time", 1)), 1)
                state = c.get("state", "")

                risk = 0
                reasons = []
                if subnet_counts[subnet] >= 3:
                    risk += 45; reasons.append("subnet_cluster")
                if live_t > 180 and (recv_c + 1) / (send_c + 1) < 0.05:
                    risk += 35; reasons.append("passive_ratio")
                if state not in ("state_normal", "state_synchronizing") and live_t > 90:
                    risk += 25; reasons.append(f"bad_state:{state}")

                if risk >= 60 and ip not in flagged_ips:
                    flagged_ips.add(ip)
                    log_alert("SYBIL_CANDIDATE", {"ip": ip, "risk_score": risk, "reasons": reasons, "dry_run": DRY_RUN})
                    if not DRY_RUN:
                        bans_to_send.append({"host": ip, "ban": True, "seconds": 86400})
                        banned_total += 1

            if bans_to_send:
                json_rpc("set_bans", {"bans": bans_to_send})

            avg_bt, drift_bt, timing_status = analyze_block_timing(h)
            if timing_status != "NORMAL":
                log_alert("BLOCK_TIMING_ANOMALY", {"height": h, "avg_s": avg_bt, "drift": drift_bt})

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
                "timing_z_score": drift_bt,
                "anomaly_status": timing_status,
                "reorgs_detected": reorgs_detected,
                "banned_sybil_total": banned_total,
                "status": "DRY_RUN" if DRY_RUN else "ACTIVE",
            }
            save_metrics(metrics)
            if cycle % 5 == 1:
                print(f"[OBX-Monitor v2.1] Ciclo #{cycle} | Altura: {h} | Pares: {len(conns)} | T.Bloque: {avg_bt}s | DryRun: {DRY_RUN}", flush=True)

        except Exception as e:
            print(f"[OBX-Monitor-WARN] Esperando RPC obsidianxd: {e}", flush=True)

        time.sleep(20.0)


if __name__ == "__main__":
    main()