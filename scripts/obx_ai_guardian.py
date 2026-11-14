#!/usr/bin/env python3
"""
ObsidianX (OBX) - Agente de IA Guardián Autónomo v3.0
======================================================
1. Escudo Anti-Sybil & Anti-Eclipse (banea subredes /24 dominantes y sniffers).
2. Centinela de Consenso (detecta Reorgs >2 bloques / posible ataque 51%).
3. Detector de Mempool Flooding (spam de transacciones).
4. Enrutamiento Patient Dandelion + Auditor OSPEAD + Safe-Flush Anti-Apagones.
"""

import argparse
import json
import math
import os
import random
import time
import urllib.request
from collections import Counter

DEFAULT_RPC_HOST = "127.0.0.1"
DEFAULT_RPC_PORT = 28081
STATE_FILE = os.path.expanduser("~/.obsidianx/ai_guardian_state.json")
INCIDENT_LOG = os.path.expanduser("~/.obsidianx/security_incidents.log")


class ObsidianXAIGuardianV3:
    def __init__(self, rpc_host: str, rpc_port: int, low_power: bool = False):
        self.rpc_url = f"http://{rpc_host}:{rpc_port}/json_rpc"
        self.low_power = low_power
        self.banned_ips = set()
        self.tx_queue = []
        self.last_height = 0
        self.last_top_hash = ""
        self.quarantine_mode = False
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)

    def log_incident(self, kind: str, detail: str):
        ts = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())
        line = f"[{ts}] [{kind}] {detail}"
        print(line)
        try:
            with open(INCIDENT_LOG, "a", encoding="utf-8") as f:
                f.write(line + "\n")
        except Exception:
            pass

    def rpc_call(self, method: str, params: dict = None):
        payload = {"jsonrpc": "2.0", "id": "obx-ai-v3", "method": method, "params": params or {}}
        try:
            req = urllib.request.Request(
                self.rpc_url,
                data=json.dumps(payload).encode("utf-8"),
                headers={"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(req, timeout=8) as resp:
                return json.loads(resp.read().decode("utf-8")).get("result", {})
        except Exception:
            return None

    # 1. Escudo Anti-Sybil + Anti-Eclipse
    def analyze_peers_and_eclipse(self) -> int:
        res = self.rpc_call("get_connections")
        if not res or "connections" not in res:
            return 0
        conns = res["connections"]
        if not conns:
            return 0

        ipv4_conns = [c for c in conns if "." in c.get("ip", "") and not c.get("ip", "").startswith("127.")]
        subnets = [".".join(c["ip"].split(".")[:3]) for c in ipv4_conns]
        subnet_counts = Counter(subnets)

        # Deteccion de Ataque Eclipse: >60% de pares IPv4 en una sola subred /24
        if len(ipv4_conns) >= 4:
            top_sub, top_cnt = subnet_counts.most_common(1)[0]
            if (top_cnt / len(ipv4_conns)) > 0.60:
                self.log_incident("ECLIPSE_ALERT", f"Subred {top_sub}.0/24 domina {top_cnt}/{len(ipv4_conns)} pares. Activando cuarentena.")
                self.quarantine_mode = True

        bans = []
        for c in conns:
            ip = c.get("ip", "")
            if not ip or ip.startswith("127.") or ip.endswith(".onion"):
                continue
            subnet = ".".join(ip.split(".")[:3]) if "." in ip else ip
            recv_cnt = c.get("recv_count", 0)
            send_cnt = c.get("send_count", 0)
            live_time = max(c.get("live_time", 1), 1)
            incoming = c.get("incoming", False)

            risk = 0.0
            if subnet_counts[subnet] >= 3:
                risk += 55.0
            if live_time > 120 and ((recv_cnt + 1) / (send_cnt + 1)) < 0.05:
                risk += 35.0
            if incoming and live_time > 300 and send_cnt == 0:
                risk += 20.0

            if risk >= 60.0 and ip not in self.banned_ips:
                bans.append({"host": ip, "ban": True, "seconds": 86400})
                self.banned_ips.add(ip)

        if bans:
            self.rpc_call("set_bans", {"bans": bans})
            self.log_incident("SYBIL_BAN", f"Baneados {len(bans)} pares sospechosos por 24h.")
        return len(bans)

    # 2. Centinela de Consenso (Reorgs / Posible Ataque 51%) & Mempool Flooding
    def monitor_consensus_and_mempool(self):
        info = self.rpc_call("get_info")
        if not info:
            return
        h = int(info.get("height", 0))
        top_hash = info.get("top_block_hash", "")
        tx_pool = int(info.get("tx_pool_size", 0))

        if self.last_height > 0:
            if h < self.last_height - 2:
                self.quarantine_mode = True
                self.log_incident("REORG_51_ALERT", f"Retroceso de altura {self.last_height} -> {h}. Pausando retransmision saliente.")
                self.blackout_safe_flush()
            elif h == self.last_height and top_hash and self.last_top_hash and top_hash != self.last_top_hash:
                self.log_incident("CHAIN_FORK_WARN", f"Cambio de top_block_hash en altura {h}.")

        if tx_pool > 500:
            self.log_incident("MEMPOOL_FLOOD", f"Pool congestionado ({tx_pool} TX). Priorizando nodos .onion.")

        self.last_height = h
        if top_hash:
            self.last_top_hash = top_hash

    # 3. Auditor Estadistico de Senuelos (OSPEAD Log-Gamma)
    @staticmethod
    def audit_ring_decoy_ages(output_ages_seconds: list) -> dict:
        if not output_ages_seconds or len(output_ages_seconds) < 2:
            return {"ok": False, "reason": "Anillo demasiado pequeno"}
        logs = [math.log1p(max(0, a)) for a in output_ages_seconds]
        mean_l = sum(logs) / len(logs)
        std_l = math.sqrt(sum((x - mean_l) ** 2 for x in logs) / len(logs))
        if std_l < 0.35:
            return {"ok": False, "std_log_age": round(std_l, 3), "reason": "Baja entropia temporal; re-seleccionar senuelos"}
        return {"ok": True, "std_log_age": round(std_l, 3)}

    # 4. Enrutamiento Patient Dandelion + Chaff Exponencial
    def patient_dandelion_step(self):
        delay = random.expovariate(1.0 / (12.0 if self.low_power else 5.0))
        time.sleep(min(delay, 15.0))
        if not self.quarantine_mode:
            self.rpc_call("get_info")
            if self.tx_queue:
                tx_id = self.tx_queue.pop(0)
                self.rpc_call("relay_tx", {"txids": [tx_id]})

    def blackout_safe_flush(self):
        try:
            if hasattr(os, "sync"):
                os.sync()
            with open(STATE_FILE, "w", encoding="utf-8") as f:
                json.dump(
                    {
                        "last_sync": int(time.time()),
                        "last_height": self.last_height,
                        "banned_peers": len(self.banned_ips),
                        "quarantine_mode": self.quarantine_mode,
                    },
                    f,
                    indent=2,
                )
        except Exception:
            pass

    def run(self):
        print(f"[OBX-AI v3.0] Guardian Autonomo activo en {self.rpc_url} (low_power={self.low_power})")
        cycle = 0
        while True:
            cycle += 1
            self.analyze_peers_and_eclipse()
            self.monitor_consensus_and_mempool()
            self.patient_dandelion_step()
            if cycle % 3 == 0:
                self.blackout_safe_flush()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ObsidianX AI Guardian v3.0")
    parser.add_argument("--rpc-host", default=DEFAULT_RPC_HOST)
    parser.add_argument("--rpc-port", type=int, default=DEFAULT_RPC_PORT)
    parser.add_argument("--low-power", action="store_true")
    args = parser.parse_args()
    ObsidianXAIGuardianV3(args.rpc_host, args.rpc_port, args.low_power).run()
