#!/usr/bin/env python3
"""ObsidianX (OBX) - Read-Only Block Explorer + Real AI Guardian Telemetry"""
import html, http.server, json, os, socketserver, time, urllib.request

DAEMON_RPC = "http://127.0.0.1:38081/json_rpc"
METRICS_FILE = os.path.expanduser("~/obsidianx/runtime/guardian_metrics.json")
WEB_PORT = 8080


def rpc_call(method: str, params: dict = None):
    payload = json.dumps({"jsonrpc": "2.0", "id": "0", "method": method, "params": params or {}}).encode("utf-8")
    req = urllib.request.Request(DAEMON_RPC, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=4) as r:
        return json.loads(r.read().decode("utf-8")).get("result", {})


def load_guardian_metrics():
    if os.path.exists(METRICS_FILE):
        try:
            with open(METRICS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"status": "OFFLINE", "peers_analyzed": 0, "banned_sybil_total": 0, "avg_block_time_s": 0.0, "anomaly_status": "N/A", "reorgs_detected": 0, "timestamp": "N/A"}


class ReadOnlyExplorerHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        gm = load_guardian_metrics()
        if self.path == "/api/info":
            try:
                info = rpc_call("get_info")
                body = json.dumps({
                    "height": info.get("height", 0),
                    "difficulty": info.get("difficulty", 0),
                    "top_block_hash": info.get("top_block_hash", ""),
                    "incoming_connections_count": info.get("incoming_connections_count", 0),
                    "outgoing_connections_count": info.get("outgoing_connections_count", 0),
                    "status": info.get("status", "OK"),
                    "ai_guardian": gm,
                }).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(body)
            except Exception:
                self.send_response(503)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "obsidianxd daemon offline"}).encode("utf-8"))
            return

        try:
            info = rpc_call("get_info")
            height = int(info.get("height", 0))
            diff = int(info.get("difficulty", 0))
            peers_in = int(info.get("incoming_connections_count", 0))
            peers_out = int(info.get("outgoing_connections_count", 0))
            blocks = []
            for h in range(max(0, height - 15), height):
                hdr = rpc_call("get_block_header_by_height", {"height": h}).get("block_header", {})
                if hdr:
                    blocks.append(hdr)
            daemon_online = True
        except Exception:
            height, diff, peers_in, peers_out = 0, 0, 0, 0
            blocks = []
            daemon_online = False

        rows = ""
        for b in reversed(blocks):
            bh = int(b.get("height", 0))
            bhash = html.escape(str(b.get("hash", "")))
            rew = float(b.get("reward", 0)) / 1e12
            bdiff = int(b.get("difficulty", 0))
            ts = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime(int(b.get("timestamp", 0))))
            rows += f"<tr><td>#{bh}</td><td class='mono'>{bhash}</td><td class='green'>{rew:.4f} OBX</td><td>{bdiff}</td><td>{html.escape(ts)}</td></tr>"

        if not rows:
            rows = "<tr><td colspan='5' style='text-align:center;color:#94a3b8;'>Esperando conexion con obsidianxd RPC...</td></tr>"

        badge_cls = "pill-ok" if daemon_online else "pill-off"
        badge_lbl = f"ONLINE ({peers_in} IN / {peers_out} OUT)" if daemon_online else "OFFLINE"
        ai_status = html.escape(str(gm.get("status", "OFFLINE")))
        ai_anom = html.escape(str(gm.get("anomaly_status", "N/A")))
        ai_ts = html.escape(str(gm.get("timestamp", "N/A")))

        page = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="5">
<title>ObsidianX (OBX) — Explorador C++ & AI Guardian</title>
<style>
  body {{ background:#070b14; color:#e2e8f0; font-family:system-ui,sans-serif; margin:0; padding:24px; }}
  .wrap {{ max-width:1100px; margin:0 auto; }}
  .hdr {{ display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #1e293b; padding-bottom:16px; margin-bottom:20px; }}
  .pill-ok {{ background:#065f46; color:#34d399; padding:6px 14px; border-radius:999px; font-weight:700; font-size:13px; }}
  .pill-off {{ background:#7f1d1d; color:#fca5a5; padding:6px 14px; border-radius:999px; font-weight:700; font-size:13px; }}
  .grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:14px; margin-bottom:18px; }}
  .card {{ background:#0f172a; border:1px solid #1e293b; border-radius:12px; padding:16px; }}
  .ai-bar {{ background:#0b1324; border:1px solid #1e3a8a; border-radius:12px; padding:14px 18px; margin-bottom:20px; display:flex; flex-wrap:wrap; gap:20px; justify-content:space-between; font-size:13px; }}
  .lbl {{ font-size:11px; color:#94a3b8; text-transform:uppercase; }}
  .val {{ font-size:22px; font-weight:700; margin-top:6px; }}
  table {{ width:100%; border-collapse:collapse; background:#0f172a; border:1px solid #1e293b; border-radius:12px; overflow:hidden; }}
  th {{ background:#1e293b; color:#94a3b8; text-align:left; padding:12px 16px; font-size:12px; text-transform:uppercase; }}
  td {{ padding:12px 16px; border-top:1px solid #1e293b; font-size:14px; }}
  .mono {{ font-family:monospace; color:#38bdf8; font-size:13px; }}
  .green {{ color:#34d399; font-weight:700; }}
</style>
</head>
<body>
<div class="wrap">
  <div class="hdr">
    <div>
      <h1 style="margin:0;font-size:22px;color:#38bdf8;">ObsidianX (OBX) — Explorador C++ & AI Guardian</h1>
      <div style="color:#94a3b8;font-size:13px;margin-top:4px;">Lectura directa desde obsidianxd RPC (127.0.0.1:38081) • Seed: 92.5.87.63:38080</div>
    </div>
    <div class="{badge_cls}">{badge_lbl}</div>
  </div>
  <div class="grid">
    <div class="card"><div class="lbl">Altura Real (C++)</div><div class="val">{height} Bloques</div></div>
    <div class="card"><div class="lbl">Dificultad PoW</div><div class="val">{diff}</div></div>
    <div class="card"><div class="lbl">Pares P2P</div><div class="val">{peers_in} IN / {peers_out} OUT</div></div>
    <div class="card"><div class="lbl">Tiempo Medio Bloque</div><div class="val">{gm.get('avg_block_time_s', 0)}s</div></div>
  </div>
  <div class="ai-bar">
    <div><span class="lbl">AI Guardian:</span> <strong style="color:#34d399;">{ai_status}</strong></div>
    <div><span class="lbl">Pares Auditados:</span> <strong>{int(gm.get('peers_analyzed', 0))}</strong></div>
    <div><span class="lbl">Baneos Sybil:</span> <strong>{int(gm.get('banned_sybil_total', 0))}</strong></div>
    <div><span class="lbl">Anomalia Z-Score:</span> <strong>{ai_anom} (Z={gm.get('timing_z_score', 0)})</strong></div>
    <div><span class="lbl">Reorgs:</span> <strong>{int(gm.get('reorgs_detected', 0))}</strong></div>
    <div><span class="lbl">Ultima Auditoria:</span> <strong>{ai_ts}</strong></div>
  </div>
  <table>
    <thead><tr><th>Altura</th><th>Hash del Bloque</th><th>Recompensa</th><th>Dificultad</th><th>Fecha UTC</th></tr></thead>
    <tbody>{rows}</tbody>
  </table>
</div>
</body>
</html>"""
        body = page.encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class ThreadingExplorerServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


if __name__ == "__main__":
    with ThreadingExplorerServer(("0.0.0.0", WEB_PORT), ReadOnlyExplorerHandler) as srv:
        srv.serve_forever()
