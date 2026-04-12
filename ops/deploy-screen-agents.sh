#!/bin/bash
# deploy-screen-agents.sh — Deploys screen-agent to all council Mac machines from Mac Mini
#
# Runs from Mac Mini. For each online council Mac:
#   1. Copies screen-agent.sh to a stable path (~/.admiranext/screen-agent.sh)
#   2. Installs/updates the LaunchAgent plist
#   3. Restarts the agent
#
# Usage: ./deploy-screen-agents.sh [--dry-run]
#
# Requirements:
#   - SSH key: ~/.ssh/admiranext_ed25519
#   - Tailscale active on Mac Mini

set -eo pipefail

SSH_KEY="$HOME/.ssh/admiranext_ed25519"
SSH_OPTS="-i $SSH_KEY -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_SRC="$SCRIPT_DIR/screen-agent.sh"
SERVER_URL="https://macmini.tail48b61c.ts.net"
INTERVAL=30
DRY_RUN="${1:-}"

REMOTE_DIR=".admiranext"
REMOTE_SCRIPT="$REMOTE_DIR/screen-agent.sh"
PLIST_NAME="com.admiranext.screen-agent"
PLIST_PATH="Library/LaunchAgents/$PLIST_NAME.plist"

# Council machines: "id:ip" pairs (bash 3.2 compatible, skip Mac Mini)
MACHINE_LIST="
admira-macbookpronegro14:100.101.192.1
admira-macbookair16:100.99.176.126
admira-macbookairluna:100.98.68.63
admira-macbook-carla:100.110.80.2
admira-macbookairblanco:100.75.118.75
admira-macbookairnines:100.76.96.50
admira-macbookairazul:100.84.81.45
"

generate_plist() {
  local machine_id="$1"
  cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$PLIST_NAME</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>/Users/csilvasantin/$REMOTE_SCRIPT</string>
    <string>$machine_id</string>
    <string>$INTERVAL</string>
    <string>$SERVER_URL</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>LimitLoadToSessionType</key>
  <array><string>Aqua</string></array>
  <key>StandardOutPath</key>
  <string>/tmp/screen-agent.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/screen-agent.log</string>
</dict>
</plist>
PLIST
}

deploy_to_machine() {
  local machine_id="$1"
  local ip="$2"
  local user="csilvasantin"
  local target="$user@$ip"

  echo ""
  echo "--- $machine_id ($ip) ---"

  # Test connectivity
  if ! ssh $SSH_OPTS "$target" "echo OK" >/dev/null 2>&1; then
    echo "  x Offline -- skipping"
    return 1
  fi
  echo "  OK Online"

  if [ "$DRY_RUN" = "--dry-run" ]; then
    echo "  -> [dry-run] Would deploy screen-agent.sh and plist"
    return 0
  fi

  # Create remote dir
  ssh $SSH_OPTS "$target" "mkdir -p ~/$REMOTE_DIR" 2>/dev/null

  # Copy screen-agent.sh
  scp $SSH_OPTS "$AGENT_SRC" "$target:~/$REMOTE_SCRIPT" >/dev/null 2>&1
  ssh $SSH_OPTS "$target" "chmod +x ~/$REMOTE_SCRIPT"
  echo "  OK Script copied to ~/$REMOTE_SCRIPT"

  # Generate and install plist
  generate_plist "$machine_id" | ssh $SSH_OPTS "$target" "cat > ~/$PLIST_PATH"
  echo "  OK Plist installed at ~/$PLIST_PATH"

  # Stop old agents (any location)
  ssh $SSH_OPTS "$target" "pkill -9 -f screen-agent 2>/dev/null; launchctl bootout gui/\$(id -u) ~/Library/LaunchAgents/$PLIST_NAME.plist 2>/dev/null; true"
  sleep 1

  # Start new agent
  ssh $SSH_OPTS "$target" "launchctl bootstrap gui/\$(id -u) ~/$PLIST_PATH 2>/dev/null; true"
  echo "  OK Agent restarted (launchd Aqua)"

  # Clean up old /tmp copies
  ssh $SSH_OPTS "$target" "rm -f /tmp/screen-agent.sh /tmp/screen-agent.py 2>/dev/null; true"

  # Verify
  sleep 2
  local running
  running=$(ssh $SSH_OPTS "$target" "pgrep -f 'screen-agent.sh' | wc -l | tr -d ' '" 2>/dev/null || echo "0")
  if [ "$running" -gt 0 ] 2>/dev/null; then
    echo "  OK Running ($running processes)"
  else
    echo "  x NOT RUNNING -- check launchd logs"
  fi
}

echo "========================================"
echo "  AdmiraNext Screen Agent Deploy"
echo "========================================"
echo ""
echo "Source: $AGENT_SRC"
echo "Server: $SERVER_URL"
echo "Interval: ${INTERVAL}s"
if [ "$DRY_RUN" = "--dry-run" ]; then
  echo "Mode: DRY RUN"
fi
echo ""

SUCCESS=0
FAIL=0

for entry in $MACHINE_LIST; do
  machine_id="${entry%%:*}"
  ip="${entry##*:}"
  if [ -z "$machine_id" ] || [ -z "$ip" ]; then
    continue
  fi
  if deploy_to_machine "$machine_id" "$ip"; then
    SUCCESS=$((SUCCESS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
done

echo ""
echo "--- Summary ---"
echo "  Deployed: $SUCCESS"
echo "  Offline:  $FAIL"
echo ""
echo "Done. Screen agents report to $SERVER_URL/api/screenshots/<machine-id>"
