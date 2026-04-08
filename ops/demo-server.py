#!/usr/bin/env python3
"""
demo-server.py — Servidor ligero para demos en directo.

Endpoints:
  GET /status              — Estado Tailscale en vivo (JSON)
  GET /screenshot/{id}     — Captura de pantalla JPEG via SSH
  GET /ping                — Health check

La pagina admiranext.html lo consulta cada 3s en modo DEMO.

Uso:
  python ops/demo-server.py
"""

import base64
import json
import re
import subprocess
import time
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

PORT = 3031
MACHINES_PATH = Path(__file__).resolve().parent.parent / "data" / "machines.json"
SSH_USER = "csilvasantin"
SSH_KEY = str(Path.home() / ".ssh" / "id_ed25519")

# Cache de screenshots: {machine_id: (timestamp, jpeg_bytes)}
screenshot_cache = {}
CACHE_TTL = 5  # segundos

TAILSCALE_TO_ID = {
    "macmini":              "admira-macmini",
    "macbookairnines":      "admira-macbookairnines",
    "macbookpronegro14":    "admira-macbookpronegro14",
    "macbookair16":         "admira-macbookair16",
    "macbookairluna":       "admira-macbookairluna",
    "macbookairluna-1":     "admira-macbookairazul",
    "macbook-air-de-carla": "admira-macbook-carla",
    "macbookairblanco":     "admira-macbookairblanco",
    "macbookairplata":      "admira-macbookairplata",
    "macbookairazul":       "admira-macbookairazul",
}


def get_tailscale_live():
    """Ejecuta tailscale status y devuelve dict {machine_id: online/offline}."""
    try:
        result = subprocess.run(
            ["tailscale", "status"], capture_output=True, text=True, timeout=5
        )
    except Exception:
        return {}

    status = {}
    for line in result.stdout.strip().splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        hostname = parts[1]
        rest = " ".join(parts[4:])
        is_offline = "offline" in rest
        machine_id = TAILSCALE_TO_ID.get(hostname)
        if machine_id:
            status[machine_id] = "offline" if is_offline else "online"
    return status


def build_response():
    """Lee machines.json y sobreescribe status con Tailscale en vivo."""
    try:
        data = json.loads(MACHINES_PATH.read_text(encoding="utf-8"))
    except Exception:
        data = {"machines": []}

    live = get_tailscale_live()

    for m in data.machines if hasattr(data, 'machines') else data.get("machines", []):
        ts_status = live.get(m["id"])
        if ts_status:
            m["status"] = ts_status

    return data


def get_machine_ip(machine_id):
    """Busca la IP de Tailscale de una maquina en machines.json."""
    try:
        data = json.loads(MACHINES_PATH.read_text(encoding="utf-8"))
    except Exception:
        return None
    for m in data.get("machines", []):
        if m["id"] == machine_id:
            ip = m.get("ssh", {}).get("ip_tailscale", "")
            return ip if ip else None
    return None


def capture_screenshot(machine_id):
    """SSH a un Mac y captura la pantalla via Quartz. Devuelve bytes JPEG o None."""
    # Check cache
    cached = screenshot_cache.get(machine_id)
    if cached and (time.time() - cached[0]) < CACHE_TTL:
        return cached[1]

    ip = get_machine_ip(machine_id)
    if not ip:
        return None

    # One-liner: Quartz capture → sips resize → base64 → stdout
    remote_cmd = (
        "python3 -c '"
        "import Quartz,sys;"
        "img=Quartz.CGWindowListCreateImage(Quartz.CGRectInfinite,Quartz.kCGWindowListOptionOnScreenOnly,Quartz.kCGNullWindowID,Quartz.kCGWindowImageDefault);"
        "sys.exit(1) if not img else None;"
        "u=Quartz.CFURLCreateWithString(None,\"file:///tmp/tw_demo.jpg\",None);"
        "d=Quartz.CGImageDestinationCreateWithURL(u,\"public.jpeg\",1,None);"
        "Quartz.CGImageDestinationAddImage(d,img,{Quartz.kCGImageDestinationLossyCompressionQuality:0.5});"
        "Quartz.CGImageDestinationFinalize(d)"
        "' && sips -Z 960 /tmp/tw_demo.jpg --out /tmp/tw_demo.jpg > /dev/null 2>&1;"
        " base64 -i /tmp/tw_demo.jpg;"
        " rm -f /tmp/tw_demo.jpg"
    )

    ssh_cmd = [
        "ssh",
        "-o", "ConnectTimeout=4",
        "-o", "StrictHostKeyChecking=no",
        "-o", "BatchMode=yes",
        "-i", SSH_KEY,
        f"{SSH_USER}@{ip}",
        remote_cmd,
    ]

    try:
        result = subprocess.run(ssh_cmd, capture_output=True, text=True, timeout=15)
        raw = result.stdout.strip()
        if not raw:
            print(f"[SCREENSHOT] {machine_id}: empty (rc={result.returncode}) {result.stderr[:100]}")
            return None

        jpeg_bytes = base64.b64decode(raw)
        if len(jpeg_bytes) < 1000:
            print(f"[SCREENSHOT] {machine_id}: too small ({len(jpeg_bytes)}B)")
            return None

        screenshot_cache[machine_id] = (time.time(), jpeg_bytes)
        print(f"[SCREENSHOT] {machine_id}: OK ({len(jpeg_bytes)//1024}KB)")
        return jpeg_bytes

    except Exception as e:
        print(f"[SCREENSHOT] {machine_id}: error {e}")
        return None


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/status" or self.path.startswith("/status?"):
            payload = build_response()
            body = json.dumps(payload).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Cache-Control", "no-cache")
            self.end_headers()
            self.write(body)
        elif self.path.startswith("/screenshot/"):
            machine_id = self.path.split("/screenshot/")[1].split("?")[0]
            print(f"[SCREENSHOT] Request for: {machine_id}")
            jpeg = capture_screenshot(machine_id)
            if jpeg:
                self.send_response(200)
                self.send_header("Content-Type", "image/jpeg")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.send_header("Cache-Control", "no-cache")
                self.end_headers()
                self.write(jpeg)
            else:
                self.send_response(404)
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
        elif self.path == "/ping":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.write(b"pong")
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def write(self, data):
        self.wfile.write(data)

    def log_message(self, format, *args):
        status_line = args[0] if args else ""
        if "/ping" not in str(status_line):
            print(f"[DEMO] {self.address_string()} {format % args}")


class ThreadedHTTPServer(HTTPServer):
    """Handle each request in a separate thread."""
    from socketserver import ThreadingMixIn
    pass

# Apply mixin dynamically
from socketserver import ThreadingMixIn

class ThreadedServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True


if __name__ == "__main__":
    print(f"Demo server en http://localhost:{PORT}/status")
    print("La pagina admiranext.html consulta este endpoint en modo DEMO.")
    print("Multithreaded: las capturas SSH no bloquean el servidor.")
    print("Ctrl+C para parar.\n")
    ThreadedServer(("127.0.0.1", PORT), Handler).serve_forever()
