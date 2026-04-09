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

PORT = 3032
MACHINES_PATH = Path(__file__).resolve().parent.parent / "data" / "machines.json"
SSH_USER = "csilvasantin"
SSH_KEY = str(Path.home() / ".ssh" / "id_ed25519")

# Cache de screenshots: {machine_id: (timestamp, jpeg_bytes)}
screenshot_cache = {}
CACHE_TTL = 5  # segundos

# Status overrides from toggle buttons: {machine_id: "online"|"offline"}
# These override Tailscale status until cleared or server restarts
status_overrides = {}

# MAC addresses for Wake on LAN (en0 interface)
WOL_MACS = {
    "admira-macbookair16":     "fe:e3:3e:4d:b6:70",
    "admira-macbookairplata":  "c6:87:57:bd:78:74",
    "admira-macbookaircrema":    "b2:ad:f6:de:d7:0e",
    "admira-macbookairazul":   "a6:57:10:7e:31:dc",
    "admira-macmini":          "",  # TODO: obtener MAC
    "admira-macbookpronegro14":"",  # TODO: obtener MAC
    "admira-macbookairluna":   "",  # TODO: obtener MAC
    "admira-macbookairblanco": "",  # TODO: obtener MAC
}

TAILSCALE_TO_ID = {
    "macmini":              "admira-macmini",
    "macbookaircrema":      "admira-macbookaircrema",
    "macbookpronegro14":    "admira-macbookpronegro14",
    "macbookair16":         "admira-macbookair16",
    "macbookairluna":       "admira-macbookairluna",
    "macbookaircrema-1":    "admira-macbookaircrema",
    "macbookairblanco":     "admira-macbookairblanco",
    "macbookairplata":      "admira-macbookairplata",
    "macbookairplata-1":    "admira-macbookairplata",
    "macbookairazul":       "admira-macbookairazul",
}


def get_tailscale_live():
    """Ejecuta tailscale status y devuelve dict {machine_id: online/offline}."""
    try:
        # macOS: tailscale CLI lives inside the app bundle
        ts_bin = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        result = subprocess.run(
            [ts_bin, "status"], capture_output=True, text=True, timeout=5
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
        mid = m["id"]
        # Apply Tailscale live status
        ts_status = live.get(mid)
        if ts_status:
            m["status"] = ts_status
        # Apply manual overrides (from toggle buttons)
        if mid in status_overrides:
            m["status"] = status_overrides[mid]

    return data


def send_wol(mac_address):
    """Envia un Wake-on-LAN magic packet por broadcast."""
    import socket, struct
    mac_bytes = bytes.fromhex(mac_address.replace(":", ""))
    magic = b"\xff" * 6 + mac_bytes * 16
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.sendto(magic, ("255.255.255.255", 9))
    sock.sendto(magic, ("255.255.255.255", 7))
    sock.close()


def sleep_machine(machine_id):
    """SSH al Mac y ejecuta pmset sleepnow."""
    ip = get_machine_ip(machine_id)
    if not ip:
        return False, "Sin IP"
    ssh_cmd = [
        "ssh", "-o", "ConnectTimeout=3", "-o", "StrictHostKeyChecking=no",
        "-o", "BatchMode=yes", "-i", SSH_KEY,
        f"{SSH_USER}@{ip}",
        "pmset sleepnow"
    ]
    try:
        result = subprocess.run(ssh_cmd, capture_output=True, text=True, timeout=8)
        if result.returncode == 0:
            status_overrides[machine_id] = "offline"
            print(f"[POWER] {machine_id}: sleep OK")
            return True, "Sleep enviado"
        else:
            print(f"[POWER] {machine_id}: sleep failed - {result.stderr[:100]}")
            return False, result.stderr[:100]
    except Exception as e:
        print(f"[POWER] {machine_id}: sleep error - {e}")
        return False, str(e)


def wake_machine(machine_id):
    """Envia WoL magic packet para despertar el Mac."""
    mac = WOL_MACS.get(machine_id, "")
    if not mac:
        return False, "Sin MAC address"
    try:
        send_wol(mac)
        status_overrides.pop(machine_id, None)  # Limpia override para que Tailscale detecte
        print(f"[POWER] {machine_id}: WoL enviado a {mac}")
        return True, f"WoL enviado a {mac}"
    except Exception as e:
        print(f"[POWER] {machine_id}: WoL error - {e}")
        return False, str(e)


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


def _is_blank_image(jpeg_bytes):
    """Detecta si un JPEG es una pantalla en blanco/negro (bloqueada o screensaver).
    Analiza una muestra de bytes del cuerpo JPEG: si la varianza es muy baja,
    la imagen es casi monocromatica = pantalla bloqueada."""
    # Heuristica rapida: comprimir una pantalla solida produce JPEGs pequenos
    if len(jpeg_bytes) < 8000:
        return True
    # Muestra bytes del centro del fichero (evita cabeceras JPEG)
    start = len(jpeg_bytes) // 4
    sample = jpeg_bytes[start:start + 2000]
    if not sample:
        return True
    avg = sum(sample) / len(sample)
    variance = sum((b - avg) ** 2 for b in sample) / len(sample)
    # Imagenes reales tienen varianza alta; pantallas solidas < 500
    is_blank = variance < 500
    return is_blank


# Cache persistente de la ultima captura buena por maquina (no expira)
last_good_screenshot = {}


def capture_screenshot(machine_id):
    """SSH a un Mac y captura la pantalla via Quartz. Devuelve bytes JPEG o None.
    Si la captura es una pantalla bloqueada/screensaver, devuelve la ultima buena."""
    # Check TTL cache
    cached = screenshot_cache.get(machine_id)
    if cached and (time.time() - cached[0]) < CACHE_TTL:
        return cached[1]

    ip = get_machine_ip(machine_id)
    if not ip:
        return last_good_screenshot.get(machine_id)

    # One-liner: Quartz capture -> sips resize -> base64 -> stdout
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
            return last_good_screenshot.get(machine_id)

        jpeg_bytes = base64.b64decode(raw)
        if len(jpeg_bytes) < 1000:
            print(f"[SCREENSHOT] {machine_id}: too small ({len(jpeg_bytes)}B)")
            return last_good_screenshot.get(machine_id)

        if _is_blank_image(jpeg_bytes):
            print(f"[SCREENSHOT] {machine_id}: blank/locked screen detected ({len(jpeg_bytes)//1024}KB), keeping last good")
            screenshot_cache[machine_id] = (time.time(), last_good_screenshot.get(machine_id, jpeg_bytes))
            return last_good_screenshot.get(machine_id, jpeg_bytes)

        # Captura buena: guardar en ambos caches
        screenshot_cache[machine_id] = (time.time(), jpeg_bytes)
        last_good_screenshot[machine_id] = jpeg_bytes
        print(f"[SCREENSHOT] {machine_id}: OK ({len(jpeg_bytes)//1024}KB)")
        return jpeg_bytes

    except Exception as e:
        print(f"[SCREENSHOT] {machine_id}: error {e}")
        return last_good_screenshot.get(machine_id)


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

    def do_POST(self):
        if self.path.startswith("/toggle/"):
            machine_id = self.path.split("/toggle/")[1].split("?")[0]
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length else {}
            new_status = body.get("status", "offline")

            if new_status == "clear":
                status_overrides.pop(machine_id, None)
                print(f"[TOGGLE] {machine_id}: override cleared")
            else:
                status_overrides[machine_id] = new_status
                print(f"[TOGGLE] {machine_id}: -> {new_status}")

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.write(json.dumps({"ok": True, "machine": machine_id, "status": new_status}).encode())
        elif self.path.startswith("/power/"):
            machine_id = self.path.split("/power/")[1].split("?")[0]
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length else {}
            action = body.get("action", "")

            if action == "sleep":
                ok, msg = sleep_machine(machine_id)
            elif action == "wake":
                ok, msg = wake_machine(machine_id)
            else:
                ok, msg = False, "Accion no valida (usa sleep o wake)"

            self.send_response(200 if ok else 400)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.write(json.dumps({"ok": ok, "machine": machine_id, "action": action, "message": msg}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
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
