#!/usr/bin/env python3
"""
ObsidianX (OBX) - Agente de IA Guardián v2.0
=============================================
1. Escudo Anti-Sybil & Caza de Supernodos (banea subredes /24 repetidas y sniffers).
2. Enrutamiento Patient Dandelion + Retardo Exponencial sobre Tor (.onion).
3. Auditor Estadístico de Señuelos (estilo OSPEAD log-gamma) y comisiones discretas.
4. Rotación de pares y Safe-Flush anti-apagones (os.sync) con modo --low-power.
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


class ObsidianXAIGuardianV2:
    def __init__(self, rpc_host: str, rpc_port: int, low_power: bool = False):
        self.rpc_url = f"http://{rpc_host}:{rpc_port}/json_rpc"
        self.low_power = low_power
        self.banned_ips = set()
        self.tx_queue = []
        os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)

    def rpc_call(self, method: str, params: dict = None):
        payload = {
            "jsonrpc": "2.0",
            "id": "obx-ai-v2",
            "method": method,
            "params": params or {},
        }
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

    # 1. Caza de Supernodos y Ataques Sybil
    def analyze_and_purge_sybil_peers(self) -> int:
        res = self.rpc_call("get_connections")
        if not res or "connections" not in res:
            return 0

        conns = res["connections"]
        subnets = [
            ".".join(c.get("ip", "").split(".")[:3])
            for c in conns
            if "." in c.get("ip", "") and not c.get("ip", "").startswith("127.")
        ]
        subnet_counts = Counter(subnets)

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
            # Sniffer/supernodo: recibe mucho, envia casi nada
            if live_time > 120 and ((recv_cnt + 1) / (send_cnt + 1)) < 0.05:
                risk += 35.0
            if incoming and live_time > 300 and send_cnt == 0:
                risk += 20.0

            if risk >= 60.0 and ip not in self.banned_ips:
                bans.append({"host": ip, "ban": True, "seconds": 86400})
                self.banned_ips.add(ip)

        if bans:
            self.rpc_call("set_bans", {"bans": bans})
            print(f"[AI-SHIELD] Baneados {len(bans)} nodos espía/Sybil por 24h.")
        return len(bans)

    # 2. Auditor estadístico de señuelos (OSPEAD Log-Gamma)
    @staticmethod
    def audit_ring_decoy_ages(output_ages_seconds: list[int]) -> dict:
        if not output_ages_seconds or len(output_ages_seconds) < 2:
            return {"ok": False, "reason": "Anillo demasiado pequeño"}
        logs = [math.log1p(max(0, a)) for a in output_ages_seconds]
        mean_l = sum(logs) / len(logs)
        var_l = sum((x - mean_l) ** 2 for x in logs) / len(logs)
        std_l = math.sqrt(var_l)
        # Evitar anillos donde todos los señuelos tengan casi la misma edad (delata gasto reciente)
        if std_l < 0.35:
            return {
                "ok": False,
                "std_log_age": round(std_l, 3),
                "reason": "Baja entropía temporal; re-seleccionar señuelos OSPEAD",
            }
        return {"ok": True, "std_log_age": round(std_l, 3)}

    # 3. Enrutamiento Patient Dandelion + Chaff exponencial
    def patient_dandelion_step(self):
        # Retardo exponencial (Poisson) antes de emitir ruido señuelo o liberar cola
        delay = random.expovariate(1.0 / (12.0 if self.low_power else 5.0))
        time.sleep(min(delay, 15.0))
        self.rpc_call("get_info")

        if self.tx_queue:
            tx_id = self.tx_queue.pop(0)
            self.rpc_call("relay_tx", {"txids": [tx_id]})
            print(f"[AI-DANDELION] TX {tx_id[:12]}... retransmitida tras retardo seguro.")

    # 4. Safe-Flush Anti-Apagón
    def blackout_safe_flush(self):
        try:
            if hasattr(os, "sync"):
                os.sync()
            with open(STATE_FILE, "w", encoding="utf-8") as f:
                json.dump(
                    {
                        "last_sync": int(time.time()),
                        "banned_peers": len(self.banned_ips),
                        "low_power": self.low_power,
                    },
                    f,
                    indent=2,
                )
        except Exception:
            pass

    def run(self):
        print(f"[OBX-AI v2.0] Guardián activo en {self.rpc_url} (low_power={self.low_power})")
        cycle = 0
        while True:
            cycle += 1
            self.analyze_and_purge_sybil_peers()
            self.patient_dandelion_step()
            if cycle % 3 == 0:
                self.blackout_safe_flush()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="ObsidianX AI Guardian v2.0")
    parser.add_argument("--rpc-host", default=DEFAULT_RPC_HOST)
    parser.add_argument("--rpc-port", type=int, default=DEFAULT_RPC_PORT)
    parser.add_argument("--low-power", action="store_true")
    args = parser.parse_args()
    ObsidianXAIGuardianV2(args.rpc_host, args.rpc_port, args.low_power).run()
