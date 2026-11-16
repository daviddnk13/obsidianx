#!/usr/bin/env python3
"""ObsidianX (OBX) - Daily Own-Account Mastodon Reporter (1 post / 24h max)"""
import json
import os
import time
import urllib.request

API_INFO = os.environ.get("OBX_API_INFO", "http://127.0.0.1:8080/api/info")
MASTODON_INSTANCE = os.environ.get("OBX_MASTODON_URL", "").rstrip("/")
MASTODON_TOKEN = os.environ.get("OBX_MASTODON_TOKEN", "").strip()
INTERVAL_S = int(os.environ.get("OBX_SOCIAL_INTERVAL_S", "86400"))  # 24h


def get_info():
    with urllib.request.urlopen(API_INFO, timeout=5) as r:
        return json.loads(r.read().decode("utf-8"))


def post_mastodon(text: str):
    url = f"{MASTODON_INSTANCE}/api/v1/statuses"
    data = json.dumps({"status": text, "visibility": "public"}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {MASTODON_TOKEN}",
        },
    )
    with urllib.request.urlopen(req, timeout=15) as r:
        return json.loads(r.read().decode("utf-8"))


def main():
    if not (MASTODON_INSTANCE and MASTODON_TOKEN):
        raise SystemExit("Faltan OBX_MASTODON_URL y OBX_MASTODON_TOKEN en el entorno.")
    print(f"[OBX-SOCIAL] Reporter diario iniciado para {MASTODON_INSTANCE}", flush=True)
    while True:
        try:
            info = get_info()
            if info.get("status") == "OK":
                h = int(info.get("height", 0))
                d = int(info.get("difficulty", 0))
                bt = info.get("ai_guardian", {}).get("avg_block_time_s", 0)
                msg = (
                    f"ObsidianX (OBX) Public Testnet v0.2.4-testnet\n"
                    f"Live C++ Chain (Monero v0.18.5.4 fork | LWMA-1 | RingCT + CLSAG + Tor)\n\n"
                    f"Height: #{h} | Diff: {d} | Avg Block: {bt}s\n"
                    f"Explorer: https://obsidianx-obx.duckdns.org\n"
                    f"Repo: https://github.com/daviddnk13/obsidianx\n\n"
                    f"#ObsidianX #Monero #RandomX #Privacy #OpenSource #Linux #Tor #CryptoNote"
                )
                res = post_mastodon(msg)
                print(f"[OBX-SOCIAL] Publicado en Mastodon: {res.get('url')}", flush=True)
        except Exception as e:
            print(f"[OBX-SOCIAL-WARN] {e}", flush=True)
        time.sleep(INTERVAL_S)


if __name__ == "__main__":
    main()