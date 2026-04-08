#!/usr/bin/env python3
"""
sync-tailscale-status.py
Lee `tailscale status` y actualiza data/machines.json con el estado real.
Opcionalmente hace git commit + push si hay cambios.

Uso:
  python ops/sync-tailscale-status.py          # solo actualiza el JSON
  python ops/sync-tailscale-status.py --push   # actualiza + commit + push
"""

import json
import subprocess
import sys
import re
from datetime import datetime, timezone
from pathlib import Path

MACHINES_PATH = Path(__file__).resolve().parent.parent / "data" / "machines.json"

# Mapeo hostname Tailscale -> machine id en machines.json
TAILSCALE_TO_ID = {
    "macmini":            "admira-macmini",
    "macbookaircrema":    "admira-macbook-carla",
    "macbookpronegro14":  "admira-macbookpronegro14",
    "macbookair16":       "admira-macbookair16",
    "macbookairluna":     "admira-macbookairluna",
    "macbookairblanco":   "admira-macbookairblanco",
    "macbookairplata":    "admira-macbookairplata",
    "macbookairazul":     "admira-macbookairazul",
}


def get_tailscale_status():
    """Ejecuta tailscale status y parsea el resultado."""
    result = subprocess.run(
        ["tailscale", "status"],
        capture_output=True, text=True, timeout=10
    )
    machines = {}
    for line in result.stdout.strip().splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        ip = parts[0]
        hostname = parts[1]
        # Detectar si esta offline
        rest = " ".join(parts[4:])
        if "offline" in rest:
            # Extraer last seen
            match = re.search(r"last seen (.+?)(?:,|$)", rest)
            last_seen = match.group(1).strip() if match else "unknown"
            machines[hostname] = {
                "ip": ip,
                "online": False,
                "last_seen_ago": last_seen,
            }
        else:
            machines[hostname] = {
                "ip": ip,
                "online": True,
                "last_seen_ago": "now",
            }
    return machines


def update_machines_json(ts_status):
    """Actualiza machines.json con el estado real de Tailscale."""
    data = json.loads(MACHINES_PATH.read_text(encoding="utf-8"))
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    changes = []

    for machine in data["machines"]:
        mid = machine["id"]
        # Buscar el hostname de Tailscale que corresponde a esta maquina
        ts_hostname = None
        for hostname, machine_id in TAILSCALE_TO_ID.items():
            if machine_id == mid:
                ts_hostname = hostname
                break

        if ts_hostname is None:
            continue

        ts_info = ts_status.get(ts_hostname)
        if ts_info is None:
            # No aparece en tailscale status (puede que no este registrado)
            continue

        old_status = machine["status"]
        new_status = "online" if ts_info["online"] else "offline"

        if old_status != new_status:
            changes.append(f"  {machine['name']}: {old_status} -> {new_status}")
            machine["status"] = new_status
            machine["lastSeen"] = now
            if new_status == "offline":
                machine["currentFocus"] = f"Offline — ultima conexion hace {ts_info['last_seen_ago']}"
            else:
                machine["currentFocus"] = "Online — detectado por Tailscale"

    if changes:
        data["updatedAt"] = now
        MACHINES_PATH.write_text(
            json.dumps(data, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8"
        )
        print(f"Actualizado machines.json ({len(changes)} cambios):")
        for c in changes:
            print(c)
    else:
        print("Sin cambios — el estado ya coincide con Tailscale.")

    return len(changes) > 0


def git_push():
    """Commit y push si hay cambios."""
    subprocess.run(["git", "add", "data/machines.json"], cwd=MACHINES_PATH.parent.parent)
    subprocess.run(
        ["git", "commit", "-m", "Sync estado Tailscale -> machines.json\n\nCo-Authored-By: sync-tailscale-status.py"],
        cwd=MACHINES_PATH.parent.parent
    )
    subprocess.run(["git", "push"], cwd=MACHINES_PATH.parent.parent)


def main():
    push = "--push" in sys.argv
    print(f"Leyendo tailscale status...")
    ts = get_tailscale_status()
    print(f"Encontradas {len(ts)} maquinas en la tailnet.")
    for h, info in ts.items():
        status = "ONLINE" if info["online"] else f"offline ({info['last_seen_ago']})"
        print(f"  {h}: {status}")
    print()

    changed = update_machines_json(ts)

    if changed and push:
        print("\nHaciendo git push...")
        git_push()
        print("Push completado.")
    elif changed and not push:
        print("\nUsa --push para subir los cambios a GitHub.")


if __name__ == "__main__":
    main()
