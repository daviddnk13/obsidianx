#!/usr/bin/env python3
"""
ObsidianX (OBX) - Read-Only Block Explorer connected directly to obsidianxd RPC
==============================================================================
- Connects strictly to local obsidianxd JSON-RPC (127.0.0.1:38081).
- Multi-threaded HTTP server (ThreadingHTTPServer) so slow clients never block.
- Strict html.escape() on every field (zero XSS).
- Zero unauthenticated /api/mine or /api/sync endpoints.
"""
import html, http.server, json, socketserver, time, urllib.request

DAEMON_RPC = "http://127.0.0.1:38081/json_rpc"
WEB_PORT = 8080


def rpc_call(method: str, params: dict = None):
    payload = json.dumps({"jsonrpc": "2.0", "id": "0", "method": method, "params": params or {}}).encode("utf-8")
    req = urllib.request.Request(DAEMON_RPC, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=4) as r:
        return json.loads(r.read().decode("utf-8")).get("result", {})


class ReadOnlyExplorerHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
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
                }).encode("utf-8")
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(body)
            except Exception as e:
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
            status_txt = html.escape(str(info.get("status", "OK")))
            blocks = []
            for h in range(max(0, height - 15), height):
                hdr = rpc_call("get_block_header_by_height", {"height": h}).get("block_header", {})
                if hdr:
                    blocks.append(hdr)
            daemon_online = True
        except Exception:
            height, diff, peers_in, peers_out, status_txt = 0, 0, 0, 0, "DAEMON OFFLINE"
            blocks = []
            daemon_online = False

        rows = ""
        for b in reversed(blocks):
            bh = int(b.get("height", 0))
            bhash = html.escape(str(b.get("hash", "")))
            rew = float(b.get("reward", 0)) / 1e12
            bdiff = int(b.get("difficulty", 0))
            ts = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime(int(b.get("timestamp", 0))))
            rows += (
                f"<tr><td>#{bh}</td><td class='mono'>{bhash}</td>"
                f"<td class='green'>{rew:.4f} OBX</td><td>{bdiff}</td><td>{html.escape(ts)}</td></tr>"
            )

        if not rows:
            rows = "<tr><td colspan='5' style='text-align:center;color:#94a3b8;'>Esperando conexion con obsidianxd RPC (127.0.0.1:38081)...</td></tr>"

        badge_cls = "pill-ok" if daemon_online else "pill-off"
        badge_lbl = f"ONLINE ({peers_in} IN / {peers_out} OUT)" if daemon_online else "OFFLINE (Esperando obsidianxd)"

        page = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta http-equiv="refresh" content="15">
<title>ObsidianX (OBX) — Explorador RPC Real</title>
<style>
  body {{ background:#070b14; color:#e2e8f0; font-family:system-ui,sans-serif; margin:0; padding:24px; }}
  .wrap {{ max-width:1100px; margin:0 auto; }}
  .hdr {{ display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #1e293b; padding-bottom:16px; margin-bottom:24px; }}
  .pill-ok {{ background:#065f46; color:#34d399; padding:6px 14px; border-radius:999px; font-weight:700; font-size:13px; }}
  .pill-off {{ background:#7f1d1d; color:#fca5a5; padding:6px 14px; border-radius:999px; font-weight:700; font-size:13px; }}
  .grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(200px,1fr)); gap:16px; margin-bottom:24px; }}
  .card {{ background:#0f172a; border:1px solid #1e293b; border-radius:12px; padding:18px; }}
  .lbl {{ font-size:12px; color:#94a3b8; text-transform:uppercase; }}
  .val {{ font-size:24px; font-weight:700; margin-top:6px; }}
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
      <h1 style="margin:0;font-size:22px;color:#38bdf8;">ObsidianX (OBX) — Explorador C++ en Vivo</h1>
      <div style="color:#94a3b8;font-size:13px;margin-top:4px;">Lectura directa desde obsidianxd RPC (127.0.0.1:38081)</div>
    </div>
    <div class="{badge_cls}">{badge_lbl}</div>
  </div>
  <div class="grid">
    <div class="card"><div class="lbl">Altura Real (C++)</div><div class="val">{height} Bloques</div></div>
    <div class="card"><div class="lbl">Dificultad PoW</div><div class="val">{diff}</div></div>
    <div class="card"><div class="lbl">Pares P2P</div><div class="val">{peers_in} IN / {peers_out} OUT</div></div>
    <div class="card"><div class="lbl">Estado RPC</div><div class="val">{status_txt}</div></div>
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
        print(f"[OBX-EXPLORER] Read-only RPC explorer listening on :{WEB_PORT}")
        srv.serve_forever()
