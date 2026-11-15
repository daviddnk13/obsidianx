#!/usr/bin/env python3
"""ObsidianX (OBX) - Read-Only Block Explorer + Real AI Guardian Telemetry"""
import html
import http.server
import json
import os
import socketserver
import time
import urllib.parse
import urllib.request

DAEMON_RPC = "http://127.0.0.1:38081/json_rpc"
DAEMON_HTTP = "http://127.0.0.1:38081"
METRICS_FILE = os.path.expanduser("~/obsidianx/runtime/guardian_metrics.json")
WEB_PORT = 8080
ONION_SEED = "3txl2dzhuq424zrpp6bfwfgbgjcsqcironoladfpak43utmtqxrtylid.onion:38083"


def rpc_call(method: str, params: dict = None):
    payload = json.dumps({"jsonrpc": "2.0", "id": "0", "method": method, "params": params or {}}).encode("utf-8")
    req = urllib.request.Request(DAEMON_RPC, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=4) as r:
        return json.loads(r.read().decode("utf-8")).get("result", {})


def http_post(path: str, data: dict):
    payload = json.dumps(data).encode("utf-8")
    req = urllib.request.Request(f"{DAEMON_HTTP}{path}", data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=4) as r:
        return json.loads(r.read().decode("utf-8"))


def load_guardian_metrics():
    if os.path.exists(METRICS_FILE):
        try:
            with open(METRICS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "status": "OFFLINE", "peers_analyzed": 0, "banned_sybil_total": 0,
        "avg_block_time_s": 0.0, "anomaly_status": "N/A", "reorgs_detected": 0,
        "mempool_txs": 0, "timestamp": "N/A",
    }


def render_search_result(query: str) -> str:
    q = query.strip()
    if not q:
        return ""
    q_esc = html.escape(q)
    if q.isdigit():
        try:
            blk = rpc_call("get_block", {"height": int(q)})
            hdr = blk.get("block_header", {})
            if hdr:
                txs = blk.get("tx_hashes", []) or []
                tx_links = "".join(
                    f"<li><a class='mono' href='/?q={html.escape(t)}'>{html.escape(t)}</a></li>" for t in txs
                ) or "<li style='color:#94a3b8;'>Solo transaccion coinbase (sin txs de usuario)</li>"
                rew = float(hdr.get("reward", 0)) / 1e12
                ts = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime(int(hdr.get("timestamp", 0))))
                return (
                    f"<div class='card' style='margin-bottom:20px;border-color:#38bdf8;'>"
                    f"<div style='display:flex;justify-content:space-between;align-items:center;'>"
                    f"<h2 style='margin:0;font-size:17px;color:#38bdf8;'>Bloque #{int(hdr.get('height', 0))}</h2>"
                    f"<a href='/' style='color:#94a3b8;font-size:13px;'>Volver al inicio</a></div>"
                    f"<p><strong>Hash:</strong> <span class='mono'>{html.escape(str(hdr.get('hash', '')))}</span></p>"
                    f"<p><strong>Recompensa:</strong> <span class='green'>{rew:.4f} OBX</span> | "
                    f"<strong>Dificultad:</strong> {int(hdr.get('difficulty', 0))} | "
                    f"<strong>Tamano:</strong> {int(hdr.get('block_size', 0))} B | <strong>Fecha:</strong> {html.escape(ts)}</p>"
                    f"<p style='margin-bottom:6px;'><strong>Transacciones ({len(txs)}):</strong></p><ul style='margin:0;padding-left:18px;'>{tx_links}</ul></div>"
                )
        except Exception:
            pass
    if len(q) == 64 and all(c in "0123456789abcdefABCDEF" for c in q):
        try:
            blk = rpc_call("get_block", {"hash": q})
            hdr = blk.get("block_header", {})
            if hdr:
                return render_search_result(str(hdr.get("height", "")))
        except Exception:
            pass
        try:
            res = http_post("/get_transactions", {"txs_hashes": [q], "decode_as_json": True})
            txs = res.get("txs", [])
            if txs:
                tx = txs[0]
                in_pool = bool(tx.get("in_pool", False))
                blk_h = tx.get("block_height", "Mempool")
                state_lbl = "En Mempool (Pendiente)" if in_pool else f"Confirmada en bloque #{int(blk_h)}"
                as_json = json.loads(tx.get("as_json", "{}"))
                rct_type = as_json.get("rct_signatures", {}).get("type", "N/A")
                fee = float(as_json.get("rct_signatures", {}).get("txnFee", 0)) / 1e12
                return (
                    f"<div class='card' style='margin-bottom:20px;border-color:#34d399;'>"
                    f"<div style='display:flex;justify-content:space-between;align-items:center;'>"
                    f"<h2 style='margin:0;font-size:17px;color:#34d399;'>Transaccion RingCT / CryptoNote</h2>"
                    f"<a href='/' style='color:#94a3b8;font-size:13px;'>Volver al inicio</a></div>"
                    f"<p><strong>TXID:</strong> <span class='mono'>{q_esc}</span></p>"
                    f"<p><strong>Estado:</strong> {html.escape(state_lbl)} | <strong>Tipo RingCT:</strong> {html.escape(str(rct_type))} | <strong>Comision:</strong> {fee:.6f} OBX</p>"
                    f"<p style='color:#94a3b8;font-size:12px;margin:0;'>Montos y direcciones ocultos criptograficamente en cadena (RingCT + CLSAG + Bulletproofs+).</p></div>"
                )
        except Exception:
            pass
    return (
        f"<div class='card' style='margin-bottom:20px;border-color:#f87171;'>"
        f"No se encontro bloque ni transaccion para <span class='mono'>{q_esc}</span>. "
        f"<a href='/' style='color:#38bdf8;'>Volver</a></div>"
    )


class ReadOnlyExplorerHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        gm = load_guardian_metrics()
        if parsed.path == "/api/info":
            try:
                info = rpc_call("get_info")
                body = json.dumps({
                    "height": info.get("height", 0),
                    "difficulty": info.get("difficulty", 0),
                    "top_block_hash": info.get("top_block_hash", ""),
                    "incoming_connections_count": info.get("incoming_connections_count", 0),
                    "outgoing_connections_count": info.get("outgoing_connections_count", 0),
                    "tx_pool_size": info.get("tx_pool_size", 0),
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

        qs = urllib.parse.parse_qs(parsed.query)
        q_val = qs.get("q", [""])[0]
        search_html = render_search_result(q_val) if q_val else ""
        refresh_meta = "" if q_val else '<meta http-equiv="refresh" content="5">'

        try:
            info = rpc_call("get_info")
            height = int(info.get("height", 0))
            diff = int(info.get("difficulty", 0))
            peers_in = int(info.get("incoming_connections_count", 0))
            peers_out = int(info.get("outgoing_connections_count", 0))
            pool_sz = int(info.get("tx_pool_size", 0))
            blocks = []
            for h in range(max(0, height - 15), height):
                hdr = rpc_call("get_block_header_by_height", {"height": h}).get("block_header", {})
                if hdr:
                    blocks.append(hdr)
            daemon_online = True
        except Exception:
            height, diff, peers_in, peers_out, pool_sz = 0, 0, 0, 0, 0
            blocks = []
            daemon_online = False

        rows = ""
        for b in reversed(blocks):
            bh = int(b.get("height", 0))
            bhash = html.escape(str(b.get("hash", "")))
            rew = float(b.get("reward", 0)) / 1e12
            bdiff = int(b.get("difficulty", 0))
            ntx = int(b.get("num_txes", 0))
            ts = time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime(int(b.get("timestamp", 0))))
            rows += (
                f"<tr><td><a href='/?q={bh}' style='color:#e2e8f0;font-weight:700;'>#{bh}</a></td>"
                f"<td class='mono'><a href='/?q={bhash}' style='color:#38bdf8;text-decoration:none;'>{bhash}</a></td>"
                f"<td>{ntx}</td><td class='green'>{rew:.4f} OBX</td><td>{bdiff}</td><td>{html.escape(ts)}</td></tr>"
            )

        if not rows:
            rows = "<tr><td colspan='6' style='text-align:center;color:#94a3b8;'>Esperando conexion con obsidianxd RPC...</td></tr>"

        badge_cls = "pill-ok" if daemon_online else "pill-off"
        badge_lbl = f"ONLINE ({peers_in} IN / {peers_out} OUT)" if daemon_online else "OFFLINE"
        ai_status = html.escape(str(gm.get("status", "OFFLINE")))
        ai_anom = html.escape(str(gm.get("anomaly_status", "N/A")))
        ai_ts = html.escape(str(gm.get("timestamp", "N/A")))

        page = f"""<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
{refresh_meta}
<title>ObsidianX (OBX) — Explorador C++ & AI Guardian</title>
<style>
  body {{ background:#070b14; color:#e2e8f0; font-family:system-ui,sans-serif; margin:0; padding:24px; }}
  .wrap {{ max-width:1120px; margin:0 auto; }}
  .hdr {{ display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid #1e293b; padding-bottom:16px; margin-bottom:20px; flex-wrap:wrap; gap:12px; }}
  .pill-ok {{ background:#065f46; color:#34d399; padding:6px 14px; border-radius:999px; font-weight:700; font-size:13px; }}
  .pill-off {{ background:#7f1d1d; color:#fca5a5; padding:6px 14px; border-radius:999px; font-weight:700; font-size:13px; }}
  .search-form {{ display:flex; gap:8px; margin-bottom:18px; }}
  .search-input {{ flex:1; background:#0f172a; border:1px solid #334155; border-radius:10px; padding:10px 14px; color:#e2e8f0; font-size:14px; }}
  .search-btn {{ background:#0284c7; color:#fff; border:none; border-radius:10px; padding:10px 18px; font-weight:700; cursor:pointer; }}
  .grid {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(190px,1fr)); gap:14px; margin-bottom:18px; }}
  .card {{ background:#0f172a; border:1px solid #1e293b; border-radius:12px; padding:16px; }}
  .ai-bar {{ background:#0b1324; border:1px solid #1e3a8a; border-radius:12px; padding:14px 18px; margin-bottom:20px; display:flex; flex-wrap:wrap; gap:18px; justify-content:space-between; font-size:13px; }}
  .lbl {{ font-size:11px; color:#94a3b8; text-transform:uppercase; }}
  .val {{ font-size:22px; font-weight:700; margin-top:6px; }}
  table {{ width:100%; border-collapse:collapse; background:#0f172a; border:1px solid #1e293b; border-radius:12px; overflow:hidden; margin-bottom:20px; }}
  th {{ background:#1e293b; color:#94a3b8; text-align:left; padding:12px 14px; font-size:12px; text-transform:uppercase; }}
  td {{ padding:12px 14px; border-top:1px solid #1e293b; font-size:14px; }}
  .mono {{ font-family:monospace; color:#38bdf8; font-size:13px; word-break:break-all; }}
  .green {{ color:#34d399; font-weight:700; }}
  a {{ color:#38bdf8; }}
</style>
</head>
<body>
<div class="wrap">
  <div class="hdr">
    <div>
      <h1 style="margin:0;font-size:22px;color:#38bdf8;">ObsidianX (OBX) — Explorador C++ & AI Guardian</h1>
      <div style="color:#94a3b8;font-size:13px;margin-top:4px;">Testnet Fair Launch • RingCT + CLSAG + RandomX • Seed: 92.5.87.63:38080</div>
    </div>
    <div class="{badge_cls}">{badge_lbl}</div>
  </div>
  <form class="search-form" method="GET" action="/">
    <input class="search-input" type="text" name="q" value="{html.escape(q_val)}" placeholder="Buscar por altura (ej. 5), hash de bloque o TXID...">
    <button class="search-btn" type="submit">Buscar</button>
  </form>
  {search_html}
  <div class="grid">
    <div class="card"><div class="lbl">Altura Real (C++)</div><div class="val">{height} Bloques</div></div>
    <div class="card"><div class="lbl">Dificultad PoW</div><div class="val">{diff}</div></div>
    <div class="card"><div class="lbl">Mempool</div><div class="val">{pool_sz} Txs</div></div>
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
    <thead><tr><th>Altura</th><th>Hash del Bloque</th><th>Txs</th><th>Recompensa</th><th>Dificultad</th><th>Fecha UTC</th></tr></thead>
    <tbody>{rows}</tbody>
  </table>
  <div class="card" style="font-size:13px;line-height:1.6;">
    <div class="lbl" style="margin-bottom:6px;">Conectar un Nodo a ObsidianX Testnet</div>
    <div><strong>Clearnet Seed:</strong> <span class="mono">92.5.87.63:38080</span></div>
    <div><strong>Tor Hidden Service:</strong> <span class="mono">{ONION_SEED}</span></div>
    <div><strong>Codigo Fuente &amp; Guia:</strong> <a href="https://github.com/daviddnk13/obsidianx" target="_blank">github.com/daviddnk13/obsidianx</a> • <a href="https://t.me/ObsidianX_OBX" target="_blank">Telegram @ObsidianX_OBX</a></div>
  </div>
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