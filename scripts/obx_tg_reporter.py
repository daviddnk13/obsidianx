#!/usr/bin/env python3
"""ObsidianX (OBX) - Official Telegram Status & Onboarding Bot (for own @ObsidianX_OBX channel/group)"""
import json
import os
import time
import urllib.parse
import urllib.request

API_INFO = os.environ.get("OBX_API_INFO", "http://127.0.0.1:8080/api/info")
TG_TOKEN = os.environ.get("OBX_TG_TOKEN", "").strip()
TG_CHAT = os.environ.get("OBX_TG_CHAT", "@ObsidianX_OBX").strip()
POST_EVERY_BLOCKS = int(os.environ.get("OBX_TG_BLOCK_STEP", "100"))
POST_MAX_SECONDS = int(os.environ.get("OBX_TG_MAX_SEC", "43200"))  # 12h


def get_info():
    with urllib.request.urlopen(API_INFO, timeout=5) as r:
        return json.loads(r.read().decode("utf-8"))


def tg_call(method: str, params: dict):
    url = f"https://api.telegram.org/bot{TG_TOKEN}/{method}"
    data = json.dumps(params).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.loads(r.read().decode("utf-8"))


def build_status_msg(info: dict) -> str:
    h = int(info.get("height", 0))
    d = int(info.get("difficulty", 0))
    em = info.get("emitted_obx", 0)
    pin = int(info.get("incoming_connections_count", 0))
    pout = int(info.get("outgoing_connections_count", 0))
    gm = info.get("ai_guardian", {})
    bt = gm.get("avg_block_time_s", 0)
    return (
        f"ObsidianX (OBX) Testnet - Estado en Vivo\n\n"
        f"Altura: #{h} bloques | Dificultad: {d}\n"
        f"Emision Testnet: {em} OBX | T. Bloque: {bt}s\n"
        f"Pares P2P: {pin} IN / {pout} OUT\n\n"
        f"Unirse (Linux + Docker):\n"
        f"curl -sSL https://raw.githubusercontent.com/daviddnk13/obsidianx/main/scripts/unirse_testnet.sh | bash\n\n"
        f"Explorador: https://obsidianx-obx.duckdns.org\n"
        f"GitHub: https://github.com/daviddnk13/obsidianx\n\n"
        f"#ObsidianX #OBX #Privacy #CryptoNote #RandomX #MoneroFork #Testnet #OpenSource"
    )


def main():
    if not TG_TOKEN:
        raise SystemExit("Falta OBX_TG_TOKEN en el entorno.")
    last_post_ts = 0.0
    last_milestone = -1
    offset = 0
    print(f"[OBX-TG] Bot iniciado para {TG_CHAT}", flush=True)

    while True:
        try:
            # 1) Responder comandos /estado o /unirse en el grupo propio
            updates = tg_call("getUpdates", {"offset": offset, "timeout": 5}).get("result", [])
            for u in updates:
                offset = u["update_id"] + 1
                msg = u.get("message", {})
                txt = (msg.get("text") or "").strip().lower()
                chat_id = msg.get("chat", {}).get("id")
                if not chat_id:
                    continue
                if txt.startswith("/estado") or txt.startswith("/status"):
                    info = get_info()
                    tg_call("sendMessage", {"chat_id": chat_id, "text": build_status_msg(info), "disable_web_page_preview": True})
                elif txt.startswith("/unirse") or txt.startswith("/join"):
                    tg_call("sendMessage", {
                        "chat_id": chat_id,
                        "text": (
                            "Conecta tu nodo Testnet en 1 comando (Linux + Docker):\n"
                            "curl -sSL https://raw.githubusercontent.com/daviddnk13/obsidianx/main/scripts/unirse_testnet.sh | bash\n\n"
                            "Clearnet Seed: 92.5.87.63:38080\n"
                            "Tor Restricted RPC: 3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38081\n"
                            "Guia completa: https://github.com/daviddnk13/obsidianx/blob/main/docs/TESTNET_GUIDE.md"
                        ),
                        "disable_web_page_preview": True,
                    })

        except Exception as e:
            print(f"[OBX-TG-WARN] getUpdates: {e}", flush=True)

        try:
            # 2) Publicacion automatica en canal/grupo propio cada 100 bloques o 12h
            info = get_info()
            if info.get("status") == "OK":
                h = int(info.get("height", 0))
                milestone = h // POST_EVERY_BLOCKS
                now = time.time()
                if (milestone > last_milestone and h > 0) or (now - last_post_ts >= POST_MAX_SECONDS):
                    tg_call("sendMessage", {"chat_id": TG_CHAT, "text": build_status_msg(info), "disable_web_page_preview": True})
                    last_milestone = milestone
                    last_post_ts = now
                    print(f"[OBX-TG] Publicado hito #{h} en {TG_CHAT}", flush=True)
        except Exception as e:
            print(f"[OBX-TG-WARN] {e}", flush=True)
        time.sleep(15)


if __name__ == "__main__":
    main()