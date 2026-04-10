#!/bin/bash
# hack-open-terminal.sh — Opens Terminal with a unique profile per council machine
# Uploaded to remote Mac and executed there.
# Usage: hack-open-terminal.sh <hostname> <ip>

HOST="$1"
IP="$2"

# Map each machine to a unique Terminal profile
case "$HOST" in
    MacBookAir16|macbookair16)           PROFILE="Homebrew" ;;       # CEO - Steve Jobs
    MacBookProNegro14|macbookpronegro14) PROFILE="Red Sands" ;;      # CTO - Steve Wozniak
    MacBookAirPlata|macbookairplata)     PROFILE="Ocean" ;;          # COO - Tim Cook
    MacMini|macmini)                     PROFILE="Pro" ;;            # CFO - Warren Buffett
    MacBookAirBlanco|macbookairblanco)   PROFILE="Novel" ;;          # CCO - Walt Disney
    MacBookAirAzul|macbookairazul)       PROFILE="Silver Aerogel" ;; # CDO - Dieter Rams
    AdmiraTwin|admira-pctwin)            PROFILE="Grass" ;;          # CXO - Howard Schultz
    MacBookAirCrema|macbookaircrema)     PROFILE="Man Page" ;;       # CSO - George Lucas
    *)                                   PROFILE="Basic" ;;
esac

# Step 1: Open Terminal with the assigned profile, run hack script, maximize window
osascript -e "
tell application \"Terminal\"
    activate
    set newTab to do script \"export TERM=xterm-256color; clear && bash /tmp/hack-sim.sh '$HOST' '$IP'\" in (do script \"\")
    delay 0.3
    set current settings of front window to settings set \"$PROFILE\"
    set bounds of front window to {0, 0, 3000, 2000}
end tell"

# Step 2: Try native fullscreen (Ctrl+Cmd+F) with a hard 3s timeout
# This needs Accessibility permissions — if they're missing, it hangs forever,
# so we run it in background and kill it after 3 seconds
(
    osascript -e '
tell application "System Events"
    tell process "Terminal"
        set frontmost to true
        delay 0.2
        keystroke "f" using {command down, control down}
    end tell
end tell' 2>/dev/null
) &
FS_PID=$!
sleep 3
kill $FS_PID 2>/dev/null
wait $FS_PID 2>/dev/null
exit 0
