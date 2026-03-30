#!/bin/bash
# arranque.sh — AdmiraNext Team
# Abre Claude y Codex y los posiciona en mitades del monitor principal
# Uso: bash arranque.sh

set -e

# Obtener dimensiones del monitor principal via Finder
BOUNDS=$(osascript -e 'tell application "Finder" to get bounds of window of desktop' 2>/dev/null || true)

if [ -n "$BOUNDS" ]; then
  SW=$(echo "$BOUNDS" | awk -F',' '{gsub(/ /,"",$3); print $3}')
  SH=$(echo "$BOUNDS" | awk -F',' '{gsub(/ /,"",$4); print $4}')
else
  # Fallback: resolucion tipica MacBook Pro 14"
  SW=1800
  SH=1120
fi

HW=$((SW / 2))

echo "Monitor: ${SW}x${SH}  —  mitad: ${HW}px"
echo ""
echo "  ◀ CLAUDE ($HW px)  |  CODEX ($HW px) ▶"
echo ""

# ── CLAUDE CODE (mitad izquierda) ────────────────────────────
echo "→ Abriendo Claude Code en la mitad izquierda..."
osascript <<EOF
tell application "Terminal"
  activate
  set claudeWin to do script "claude"
  delay 1.2
  set bounds of front window to {0, 25, ${HW}, ${SH}}
end tell
EOF

sleep 0.8

# ── CODEX (mitad derecha) ─────────────────────────────────────
echo "→ Abriendo Codex en la mitad derecha..."
osascript <<EOF
tell application "Terminal"
  activate
  set codexWin to do script "codex"
  delay 1.2
  set bounds of front window to {${HW}, 25, ${SW}, ${SH}}
end tell
EOF

echo ""
echo "✓ Workspace listo"
echo "  ┌─────────────────┬─────────────────┐"
echo "  │   CLAUDE CODE   │      CODEX      │"
echo "  │   (izquierda)   │    (derecha)    │"
echo "  └─────────────────┴─────────────────┘"
