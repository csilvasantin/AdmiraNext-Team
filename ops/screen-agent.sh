#!/bin/bash
# screen-agent.sh — captures screen locally and sends to AdmiraNext Control server
# Usage: screen-agent.sh <machine-id> [interval-seconds] [server-url]
#
# Before each capture, ensures Claude/Codex/Telegram is in focus.
# If another app is frontmost, switches to Claude > Codex > Telegram.

MACHINE_ID="${1:?Usage: screen-agent.sh <machine-id> [interval] [server-url]}"
INTERVAL="${2:-30}"
SERVER="${3:-https://macmini.tail48b61c.ts.net}"

TMP_FILE="/tmp/tw_screen_agent.jpg"
ALLOWED_APPS="Claude|Codex|Telegram"

echo "Screen agent started: machine=$MACHINE_ID interval=${INTERVAL}s server=$SERVER"

run_with_timeout() {
  local timeout_secs="$1"; shift
  "$@" &
  local pid=$!
  ( sleep "$timeout_secs"; kill "$pid" 2>/dev/null ) &
  local watchdog=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  return $rc
}

ensure_focus() {
  FRONT=$(run_with_timeout 5 osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
  if echo "$FRONT" | grep -qE "$ALLOWED_APPS"; then
    return 0
  fi
  # Switch focus: try Claude first, then Codex, then Telegram
  for app in Claude Codex Telegram; do
    if run_with_timeout 3 osascript -e "tell application \"System Events\" to exists process \"$app\"" 2>/dev/null | grep -q true; then
      run_with_timeout 3 osascript -e "tell application \"$app\" to activate" 2>/dev/null
      sleep 0.5
      echo "$(date +%H:%M:%S) Focus: $FRONT -> $app"
      return 0
    fi
  done
  echo "$(date +%H:%M:%S) No Claude/Codex/Telegram running"
  return 1
}

while true; do
  # Ensure correct app is in focus
  ensure_focus

  # Capture screen as JPEG — try Python+Quartz first (works without Screen Recording permission), fallback to screencapture
  python3 -c "
import Quartz
from AppKit import NSBitmapImageRep
region = Quartz.CGRectInfinite
image = Quartz.CGWindowListCreateImage(region, Quartz.kCGWindowListOptionOnScreenOnly, Quartz.kCGNullWindowID, Quartz.kCGWindowImageDefault)
if image:
    rep = NSBitmapImageRep.alloc().initWithCGImage_(image)
    data = rep.representationUsingType_properties_(3, {})
    data.writeToFile_atomically_('$TMP_FILE', True)
" 2>/dev/null
  if [ ! -s "$TMP_FILE" ]; then
    screencapture -x -t jpg "$TMP_FILE" 2>/dev/null
  fi

  if [ -f "$TMP_FILE" ] && [ -s "$TMP_FILE" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 10 \
      -X POST \
      -H "Content-Type: image/jpeg" \
      --data-binary @"$TMP_FILE" \
      "$SERVER/api/screenshots/$MACHINE_ID")

    if [ "$HTTP_CODE" = "200" ]; then
      echo "$(date +%H:%M:%S) OK ($MACHINE_ID)"
    else
      echo "$(date +%H:%M:%S) FAIL HTTP $HTTP_CODE"
    fi

    rm -f "$TMP_FILE"
  else
    echo "$(date +%H:%M:%S) screencapture failed"
  fi

  sleep "$INTERVAL"
done
