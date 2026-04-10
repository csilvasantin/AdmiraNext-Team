#!/bin/bash
# hack-sim.sh — Cinematic hacking simulation for council machines
# Usage: hack-sim.sh [hostname] [ip] [art_seed 0-7]
# Each machine gets unique visuals, quotes, data, and audio

HOST="${1:-$(hostname)}"
IP="${2:-127.0.0.1}"
ART_SEED="${3:-0}"
USER_NAME="$(whoami)"
COLS=$(tput cols 2>/dev/null || echo 80)

# ══════════════════════════════════════════════
# TERMINAL COLORS
# ══════════════════════════════════════════════
G='\033[1;32m'   # Green bold
R='\033[1;31m'   # Red bold
Y='\033[1;33m'   # Yellow bold
C='\033[1;36m'   # Cyan bold
W='\033[1;37m'   # White bold
D='\033[0;32m'   # Green dim
DG='\033[2;37m'  # Dim gray
M='\033[1;35m'   # Magenta bold
N='\033[0m'      # Reset
BG='\033[40m'    # Black background

clear
printf '\033[?25l'  # Hide cursor

# Play modem handshake sound in background (with per-machine variation)
if [ -f /tmp/modem-sound.py ]; then
    python3 /tmp/modem-sound.py "$ART_SEED" &>/dev/null &
fi

# ══════════════════════════════════════════════
# HELPER FUNCTIONS
# ══════════════════════════════════════════════

typeit() {
    local text="$1"
    local delay="${2:-0.02}"
    for ((i=0; i<${#text}; i++)); do
        printf '%s' "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

randhex() {
    cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | head -c "$1"
}

center() {
    local text="$1"
    local len=${#text}
    local pad=$(( (COLS - len) / 2 ))
    printf "%${pad}s%s\n" "" "$text"
}

draw_hline() {
    local char="${1:-═}"
    local len="${2:-$COLS}"
    printf '%*s\n' "$len" '' | tr ' ' "$char"
}

progress_bar() {
    local label="$1"
    local target="${2:-100}"
    local color="${3:-$G}"
    local width=30
    for ((pct=0; pct<=target; pct+=3)); do
        local filled=$((pct * width / 100))
        local empty=$((width - filled))
        printf "\r  ${DG}%-20s${N} ${color}[" "$label"
        printf '%0.s█' $(seq 1 $filled 2>/dev/null) 2>/dev/null
        printf '%0.s░' $(seq 1 $empty 2>/dev/null) 2>/dev/null
        printf "]${N} ${W}%3d%%${N}" "$pct"
        sleep 0.03
    done
    printf "\r  ${DG}%-20s${N} ${color}[" "$label"
    printf '%0.s█' $(seq 1 $width)
    printf "]${N} ${G}%3d%% ✓${N}\n" 100
}

log_line() {
    local color="${1:-$D}"
    local text="$2"
    echo -e "  ${DG}[$(date '+%H:%M:%S')]${N} ${color}${text}${N}"
    sleep 0.3
}

# ══════════════════════════════════════════════
# SCI-FI MOVIE QUOTES — big ASCII text banners
# ══════════════════════════════════════════════

show_quote_0() {
    echo -e "${G}"
    cat << 'Q'
 ____  _   _    _    _     _      __        ______
/ ___|| | | |  / \  | |   | |     \ \      / / ___|
\___ \| |_| | / _ \ | |   | |      \ \ /\ / /| |
 ___) |  _  |/ ___ \| |___| |___    \ V  V / | |___
|____/|_| |_/_/   \_\_____|_____|    \_/\_/   \____|
 ____  _        _ __   __
|  _ \| |      / \\ \ / /       _       ____    _    __  __ _____ ___
| |_) | |     / _ \\ V /       / \     / ___|  / \  |  \/  | ____| _ \
|  __/| |___ / ___ \| |       / _ \   | |  _  / _ \ | |\/| |  _| |_) |
|_|   |_____/_/   \_\_|      /_/ \_\   \____/_/   \_\_|  |_|_____|_|   ?
Q
    echo -e "${N}"
}

show_quote_1() {
    echo -e "${R}"
    cat << 'Q'
 ___ _   __  __   ____   ___  ____  ______   __
|_ _( ) |  \/  | / ___| / _ \|  _ \|  _ \ \ / /
 | ||/  | |\/| | \___ \| | | | |_) | |_) \ V /
 | |    | |  | |  ___) | |_| |  _ <|  _ < | |
|___|   |_|  |_| |____/ \___/|_| \_\_| \_\|_|

 ___    ____    _    _   _ _ _____     ____   ___    _____ _   _    _  _____
|_ _|  / ___|  / \  | \ | ( )_   _|   |  _ \ / _ \  |_   _| | | |  / \|_   _|
 | |  | |     / _ \ |  \| |/  | |     | | | | | | |   | | | |_| | / _ \ | |
 | |  | |___ / ___ \| |\  |   | |     | |_| | |_| |   | | |  _  |/ ___ \| |
|___|  \____/_/   \_\_| \_|   |_|     |____/ \___/    |_| |_| |_/_/   \_\_|  DAVE
Q
    echo -e "${N}"
}

show_quote_2() {
    echo -e "${R}"
    cat << 'Q'
 ___ _     _       ____  _____     ____    _    ____ _  __
|_ _( )   | |     | __ )| ____|   | __ )  / \  / ___| |/ /
 | ||/    | |     |  _ \|  _|     |  _ \ / _ \| |   | ' /
 | |      | |___  | |_) | |___    | |_) / ___ \ |___| . \
|___|     |_____| |____/|_____|   |____/_/   \_\____|_|\_\
Q
    echo -e "${N}"
}

show_quote_3() {
    echo -e "${C}"
    cat << 'Q'
 _____ ___ __  __ _____   _____ ___    ____ ___ _____
|_   _|_ _|  \/  | ____| |_   _/ _ \  |  _ \_ _| ____|
  | |  | || |\/| |  _|     | || | | | | | | | ||  _|
  | |  | || |  | | |___    | || |_| | | |_| | || |___
  |_| |___|_|  |_|_____|   |_| \___/  |____/___|_____|
              _     ___ _  ______   _____ _____    _    ____  ____
             | |   |_ _| |/ / ___| |_   _| ____|  / \  |  _ \/ ___|
             | |    | || ' /| |       | | |  _|   / _ \ | |_) \___ \
             | |___ | || . \| |___    | | | |___ / ___ \|  _ < ___) |
             |_____|___|_|\_\\____|   |_| |_____/_/   \_\_| \_\____/  IN RAIN
Q
    echo -e "${N}"
}

show_quote_4() {
    echo -e "${G}"
    cat << 'Q'
 ___ _   _   ____  ____   _    ____ _____
|_ _| \ | | / ___||  _ \ / \  / ___| ____|
 | ||  \| | \___ \| |_) / _ \| |   |  _|
 | || |\  |  ___) |  __/ ___ \ |___| |___
|___|_| \_| |____/|_| /_/   \_\____|_____|
 _   _  ___    ___  _   _ _____    ____    _    _   _   _   _ _____    _    ____
| \ | |/ _ \  / _ \| \ | | ____|  / ___|  / \  | \ | | | | | | ____|  / \  |  _ \
|  \| | | | || | | |  \| |  _|   | |     / _ \ |  \| | | |_| |  _|   / _ \ | |_) |
| |\  | |_| || |_| | |\  | |___  | |___ / ___ \| |\  | |  _  | |___ / ___ \|  _ <
|_| \_|\___/  \___/|_| \_|_____|  \____/_/   \_\_| \_| |_| |_|_____/_/   \_\_| \_\
                       __   _____  _   _   ____   ____ ____  _____    _    __  __
                       \ \ / / _ \| | | | / ___| / ___|  _ \| ____|  / \  |  \/  |
                        \ V / | | | | | | \___ \| |   | |_) |  _|   / _ \ | |\/| |
                         | || |_| | |_| |  ___) | |___|  _ <| |___ / ___ \| |  | |
                         |_| \___/ \___/  |____/ \____|_| \_\_____/_/   \_\_|  |_|
Q
    echo -e "${N}"
}

show_quote_5() {
    echo -e "${Y}"
    cat << 'Q'
  __  __    _  __   __  _____ _   _ _____   _____ ___  ____   ____ _____
 |  \/  |  / \\ \ / / |_   _| | | | ____| | ____/ _ \|  _ \ / ___| ____|
 | |\/| | / _ \\ V /    | | | |_| |  _|   |  _|| | | | |_) | |   |  _|
 | |  | |/ ___ \| |     | | |  _  | |___  | |  | |_| |  _ <| |___| |___
 |_|  |_/_/   \_\_|     |_| |_| |_|_____| |_|   \___/|_| \_\\____|_____|
    ____  _____  __        _____ _____ _   _  __   _____  _   _
   | __ )| ____| \ \      / /_ _|_   _| | | | \ \ / / _ \| | | |
   |  _ \|  _|    \ \ /\ / / | |  | | | |_| |  \ V / | | | | | |
   | |_) | |___    \ V  V /  | |  | | |  _  |   | || |_| | |_| |
   |____/|_____|    \_/\_/  |___| |_| |_| |_|   |_| \___/ \___/
Q
    echo -e "${N}"
}

show_quote_6() {
    echo -e "${G}"
    cat << 'Q'
 _____     _    _  __ _____   _____ _   _ _____
|_   _|   / \  | |/ /| ____| |_   _| | | | ____|
  | |    / _ \ | ' / |  _|     | | | |_| |  _|
  | |   / ___ \| . \ | |___    | | |  _  | |___
  |_|  /_/   \_\_|\_\|_____|   |_| |_| |_|_____|
 ____  _____ ____    ____  ___ _     _       _   _ _____ ___
|  _ \| ____|  _ \  |  _ \|_ _| |   | |     | \ | | ____/ _ \
| |_) |  _| | | | | | |_) || || |   | |     |  \| |  _|| | | |
|  _ <| |___| |_| | |  __/ | || |___| |___  | |\  | |__| |_| |
|_| \_\_____|____/  |_|   |___|_____|_____| |_| \_|_____\___/
Q
    echo -e "${N}"
}

show_quote_7() {
    echo -e "${C}"
    cat << 'Q'
  ____ ____  _____ _____ _____ ___ _   _  ____ ____
 / ___|  _ \| ____| ____|_   _|_ _| \ | |/ ___/ ___|
| |  _| |_) |  _| |  _|   | |  | ||  \| | |  _\___ \
| |_| |  _ <| |___| |___  | |  | || |\  | |_| |___) |
 \____|_| \_\_____|_____| |_| |___|_| \_|\____|____/
 _____ ____   ___  __  __   _____ _   _ _____    ____ ____  ___ ____
|  ___|  _ \ / _ \|  \/  | |_   _| | | | ____|  / ___|  _ \|_ _|  _ \
| |_  | |_) | | | | |\/| |   | | | |_| |  _|   | |  _| |_) || || | | |
|  _| |  _ <| |_| | |  | |   | | |  _  | |___  | |_| |  _ < | || |_| |
|_|   |_| \_\\___/|_|  |_|   |_| |_| |_|_____|  \____|_| \_\___|____/
Q
    echo -e "${N}"
}

show_movie_quote() {
    case $(( ($1) % 8 )) in
        0) show_quote_0 ;; 1) show_quote_1 ;; 2) show_quote_2 ;; 3) show_quote_3 ;;
        4) show_quote_4 ;; 5) show_quote_5 ;; 6) show_quote_6 ;; 7) show_quote_7 ;;
    esac
}

# ══════════════════════════════════════════════
# 8 unique ASCII art pieces — one per machine
# ══════════════════════════════════════════════

show_art_0() { echo -e "${R}"
cat << 'ART'
         _______________
        /               \
       /                 \
      |   XXXX     XXXX   |
      |   XXXX     XXXX   |
      |   XXX       XXX   |
      |         X         |
      \__      XXX     __/
        |\     XXX     /|
        | |           | |
        | I I I I I I I |
        |  I I I I I I  |
         \_           _/
           \_________/
ART
echo -e "${N}"; }

show_art_1() { echo -e "${G}"
cat << 'ART'
            .-"""-.
           /        \
          |  O    O  |
          |    __    |
          |   /  \   |
           \  '=='  /
            '------'
           /  /()\  \
          /  / /  \ \  \
         (  ( (    ) )  )
          \  \ \  / /  /
           \  /()\  /
            '-....-'
    >>> SPECTER INSIDE <<<
ART
echo -e "${N}"; }

show_art_2() { echo -e "${Y}"
cat << 'ART'
        .---------.
       / .------. \
      / /        \ \
      | |        | |
      | |        |/
      \ \        /
       \ '------'
        '----+----'
        |  .-"-.  |
        | /     \ |
        ||       ||
        ||  |||  ||
        | \ ||| / |
        |  '-+-'  |
        '---------'
   >>> LOCK BYPASSED <<<
ART
echo -e "${N}"; }

show_art_3() { echo -e "${C}"
cat << 'ART'
              .-""""""-.
           .'          '.
          /   O      O   \
         :                :
         |                |
         : ',          ,' :
          \  '-......-'  /
           '.          .'
             '-......-'
          /  |  \  /  |  \
         '   |   ''   |   '
     >>> ALL SEEING EYE <<<
ART
echo -e "${N}"; }

show_art_4() { echo -e "${R}"
cat << 'ART'
             _.-^^---....,,--
         _--                  --_
        <       LOGIC BOMB       >
         |    ARMED & READY     |
          \._                 _./
             ```--. . , ; .--'''
                   | |   |
                .-=||  | |=-.
                `-=#$%&%$#=-'
                   | ;  :|
          _____.,-#%&$@%#&#~,._____
ART
echo -e "${N}"; }

show_art_5() { echo -e "${M}"
cat << 'ART'
                   >>\.
                  /_  )`.
                 /  _)`^)`.   _.---._
                (_,' \  `^-)""      `.\\
                      |  | \         | |
                      \  / .|       /  /
                      / /  | |   .' .'
                     / /   \ \_.' .'
                    ( (     \  __.'
                     \ \     '|
                      \ \     |
                       \ \    |
                        ) )   |
                       / /    |
            >>>  TROJAN HORSE  <<<
ART
echo -e "${N}"; }

show_art_6() { echo -e "${G}"
cat << 'ART'
           /\  .-"""-.  /\
          //\\/  ,,,  \//\\
          |/\| ,;;;;;, |/\|
          //\\\;-"""-;///\\
         //  \/   .   \/  \\
        (| ,-_| \ | / |_-, |)
          //`__\.-.-./__`\\
         // /.-( \___/ )-.\\ \\
        (\ |)   '---'   (| /)
         ` (|           |) `
           \)           (/
    >>> WEB CRAWLER ACTIVE <<<
ART
echo -e "${N}"; }

show_art_7() { echo -e "${Y}"
cat << 'ART'
        ╔═══════════════════╗
        ║   ┌───────────┐   ║
        ║   │  RANSOM    │   ║
        ║   │  ████████  │   ║
        ║   │  ██ $$ ██  │   ║
        ║   │  ████████  │   ║
        ║   │  WARE  v3  │   ║
        ║   └───────────┘   ║
        ║  PAY 5 BTC OR     ║
        ║  LOSE EVERYTHING  ║
        ║  ₿ 1A1zP1...QGefi ║
        ╚═══════════════════╝
ART
echo -e "${N}"; }

show_ascii_art() {
    case $ART_SEED in
        0) show_art_0 ;; 1) show_art_1 ;; 2) show_art_2 ;; 3) show_art_3 ;;
        4) show_art_4 ;; 5) show_art_5 ;; 6) show_art_6 ;; 7) show_art_7 ;;
    esac
}

show_mid_art() {
    case $(( (ART_SEED + 4) % 8 )) in
        0) show_art_0 ;; 1) show_art_1 ;; 2) show_art_2 ;; 3) show_art_3 ;;
        4) show_art_4 ;; 5) show_art_5 ;; 6) show_art_6 ;; 7) show_art_7 ;;
    esac
}

# ══════════════════════════════════════════════
# PER-MACHINE VARIATION DATA
# ══════════════════════════════════════════════

HACKER_GROUPS=("APT-41 Shadow Panda" "Lazarus Group" "Fancy Bear (APT-28)" "Equation Group" "DarkSide Collective" "Cozy Bear (APT-29)" "Turla Snake" "Sandworm Team")
BREACH_METHODS=("Stolen RSA key" "Zero-day CVE-2026-31337" "Brute-forced SSH" "MITM certificate" "Kerberos golden ticket" "Supply chain backdoor" "Phishing payload" "DNS rebinding")
C2_SERVERS=("c2.darknet.onion" "data.shadow-nexus.tor" "exfil.blackhat-ops.i2p" "drop.phantom-grid.onion" "upload.nullbyte.tor" "relay.ghost-proto.i2p" "sink.cipher-storm.onion" "vault.zeroshell.tor")
EXFIL_SIZES=("891MB" "1.2GB" "743MB" "2.1GB" "567MB" "1.8GB" "934MB" "1.5GB")
DB_NAMES_A=("executive_strategy" "source_code" "supply_chain" "financial_records" "brand_assets" "design_prototypes" "customer_analytics" "content_library")
DB_NAMES_B=("board_minutes" "ci_cd_secrets" "vendor_contracts" "tax_filings" "campaign_data" "ux_research" "ab_test_results" "media_assets")
DB_NAMES_C=("merger_targets" "infra_keys" "logistics_data" "investor_reports" "influencer_deals" "product_roadmap" "user_sessions" "distribution_rights")
COUNCIL_NAMES=("CEO" "CTO" "COO" "CFO" "CCO" "CDO" "CXO" "CSO")
COUNCIL_HOSTS=("MacBookAir16" "MacBookProNegro14" "MacBookAirPlata" "MacMini" "MacBookAirBlanco" "MacBookAirAzul" "AdmiraTwin" "MacBookAirCrema")
COUNCIL_IPS=("100.99.176.126" "100.101.192.1" "100.114.113.88" "100.74.101.14" "100.75.118.75" "100.84.81.45" "100.121.18.12" "100.110.80.2")
KEY_TYPES=("OPENSSH PRIVATE" "RSA PRIVATE" "EC PRIVATE" "OPENSSH PRIVATE" "RSA PRIVATE" "EC PRIVATE" "OPENSSH PRIVATE" "RSA PRIVATE")

HACKER="${HACKER_GROUPS[$ART_SEED]}"
BREACH="${BREACH_METHODS[$ART_SEED]}"
C2="${C2_SERVERS[$ART_SEED]}"
EXFIL_SIZE="${EXFIL_SIZES[$ART_SEED]}"
DB_A="${DB_NAMES_A[$ART_SEED]}"
DB_B="${DB_NAMES_B[$ART_SEED]}"
DB_C="${DB_NAMES_C[$ART_SEED]}"
KEY_TYPE="${KEY_TYPES[$ART_SEED]}"

# ══════════════════════════════════════════════════════════════
# PHASE 1: MOVIE QUOTE INTRO (10s)
# ══════════════════════════════════════════════════════════════

show_movie_quote $ART_SEED
sleep 2.5
clear

# ══════════════════════════════════════════════════════════════
# PHASE 2: BOOT SEQUENCE (15s)
# ══════════════════════════════════════════════════════════════

echo
echo -e "  ${R}╔══════════════════════════════════════════════════════╗${N}"
echo -e "  ${R}║${N}  ${W}${HACKER}${N} — EXPLOIT FRAMEWORK v4.$(( ART_SEED + 2 ))           ${R}║${N}"
echo -e "  ${R}╠══════════════════════════════════════════════════════╣${N}"
echo -e "  ${R}║${N}                                                      ${R}║${N}"
echo

BOOT_ITEMS=("Kernel rootkit module" "Payload encryption" "C2 beacon channel" "Network drivers" "Anti-forensics" "Memory injector" "Privilege escalation" "Log cleaner daemon")
# Each machine loads different items in different order
for i in 0 1 2 3 4 5; do
    idx=$(( (i + ART_SEED) % 8 ))
    progress_bar "${BOOT_ITEMS[$idx]}" 100 "$G"
    sleep 0.1
done

echo
echo -e "  ${R}║${N}                                                      ${R}║${N}"
echo -e "  ${R}╚══════════════════════════════════════════════════════╝${N}"
echo
echo -e "  ${G}▶ All modules loaded. Initiating breach sequence...${N}"
sleep 1.5
clear

# ══════════════════════════════════════════════════════════════
# PHASE 3: BREACH — TARGET INFO PANEL (20s)
# ══════════════════════════════════════════════════════════════

echo
echo -e "  ${R}[!] INTRUSION DETECTED${N}"
echo -e "  ${DG}$(date '+%Y-%m-%d %H:%M:%S')${N}"
echo
echo -e "  ${C}┌─── TARGET ──────────────────┬─── BREACH LOG ─────────────────────┐${N}"
echo -e "  ${C}│${N}                              ${C}│${N}                                     ${C}│${N}"
printf  "  ${C}│${N}  ${W}Host:${N}  %-20s ${C}│${N}" "${HOST}"
log_line "$D" "> Scanning ports..."
printf  "  ${C}│${N}  ${W}IP:${N}    %-20s ${C}│${N}" "${IP}"
log_line "$Y" "> ${BREACH}..."
printf  "  ${C}│${N}  ${W}User:${N}  %-20s ${C}│${N}" "${USER_NAME}"
log_line "$G" "> Root access obtained"
printf  "  ${C}│${N}  ${W}OS:${N}    %-20s ${C}│${N}" "macOS 15.4 arm64"
log_line "$G" "> Firewall rules flushed"
printf  "  ${C}│${N}  ${W}Group:${N} %-20s ${C}│${N}" "${HACKER}"
log_line "$R" "> SYSTEM COMPROMISED"
echo -e "  ${C}│${N}                              ${C}│${N}                                     ${C}│${N}"
echo -e "  ${C}└──────────────────────────────┴─────────────────────────────────────┘${N}"
echo
sleep 2

# Show private key found
echo -e "  ${Y}── Credential Extraction ──${N}"
echo
echo -e "  ${DG}Found: ~/.ssh/id_ed25519${N}"
echo -e "  ${Y}┌─────────────────────────────────────────────────┐${N}"
echo -e "  ${Y}│${N} -----BEGIN ${KEY_TYPE} KEY-----                ${Y}│${N}"
echo -e "  ${Y}│${N} $(randhex 48)  ${Y}│${N}"
echo -e "  ${Y}│${N} $(randhex 48)  ${Y}│${N}"
echo -e "  ${Y}│${N} $(randhex 48)  ${Y}│${N}"
echo -e "  ${Y}│${N} -----END ${KEY_TYPE} KEY-----                  ${Y}│${N}"
echo -e "  ${Y}└─────────────────────────────────────────────────┘${N}"
echo
sleep 2
clear

# ══════════════════════════════════════════════════════════════
# PHASE 4: NETWORK MAP — Council topology (20s)
# ══════════════════════════════════════════════════════════════

echo
echo -e "  ${C}╔══════════════════════════════════════════════════════╗${N}"
echo -e "  ${C}║${N}  ${W}NETWORK TOPOLOGY — Tailscale Mesh${N}                    ${C}║${N}"
echo -e "  ${C}╚══════════════════════════════════════════════════════╝${N}"
echo

# Show mid-phase art
show_mid_art
sleep 1

# Network map with nodes appearing
echo -e "  ${G}    Scanning internal network...${N}"
echo
sleep 0.5

for i in 0 1 2 3 4 5 6 7; do
    if [ "$i" -eq "$ART_SEED" ]; then
        # Current machine — highlight
        printf "  ${R}  ▶ [${COUNCIL_NAMES[$i]}]${N}  ${W}%-22s${N}  ${COUNCIL_IPS[$i]}  ${R}◄ YOU ARE HERE${N}\n" "${COUNCIL_HOSTS[$i]}"
    else
        printf "  ${G}    [${COUNCIL_NAMES[$i]}]${N}  ${DG}%-22s${N}  ${COUNCIL_IPS[$i]}  ${G}VULNERABLE${N}\n" "${COUNCIL_HOSTS[$i]}"
    fi
    sleep 0.4
done

echo
echo -e "  ${D}    ┌───┐   ┌───┐   ┌───┐   ┌───┐${N}"
echo -e "  ${D}    │CEO├───┤CTO├───┤COO├───┤CFO│${N}"
echo -e "  ${D}    └─┬─┘   └─┬─┘   └─┬─┘   └─┬─┘${N}"
echo -e "  ${D}      │       │       │       │${N}"
echo -e "  ${D}    ┌─┴─┐   ┌─┴─┐   ┌─┴─┐   ┌─┴─┐${N}"
echo -e "  ${D}    │CCO├───┤CDO├───┤CXO├───┤CSO│${N}"
echo -e "  ${D}    └───┘   └───┘   └───┘   └───┘${N}"
echo
sleep 2

# Second movie quote
show_movie_quote $((ART_SEED + 3))
sleep 1.5
clear

# ══════════════════════════════════════════════════════════════
# PHASE 5: DATA EXFILTRATION (25s)
# ══════════════════════════════════════════════════════════════

echo
echo -e "  ${R}╔══════════════════════════════════════════════════════╗${N}"
echo -e "  ${R}║${N}  ${W}DATA EXFILTRATION${N}  →  ${Y}${C2}${N}       ${R}║${N}"
echo -e "  ${R}╚══════════════════════════════════════════════════════╝${N}"
echo

# Database dumps with individual progress bars
echo -e "  ${Y}── Database Extraction ──${N}"
echo
progress_bar "$DB_A" 100 "$G"
sleep 0.2
progress_bar "$DB_B" 100 "$G"
sleep 0.2
progress_bar "$DB_C" 100 "$G"
echo

# Files found table
echo -e "  ${Y}── Sensitive Files Located ──${N}"
echo
echo -e "  ${C}┌──────────────────────────────────────────┬──────────┐${N}"
echo -e "  ${C}│${N}  ${W}File${N}                                      ${C}│${N}  ${W}Status${N}  ${C}│${N}"
echo -e "  ${C}├──────────────────────────────────────────┼──────────┤${N}"

SECRET_FILES=(".ssh/id_ed25519" "projects/.env.production" "Documents/Passwords_master.kdbx" "Library/Keychains/login.keychain" ".aws/credentials" "Documents/Presupuesto_2026.xlsx")
for f in "${SECRET_FILES[@]}"; do
    printf "  ${C}│${N}  ${DG}%-40s${N}${C}│${N}  ${G}COPIED${N}  ${C}│${N}\n" "$f"
    sleep 0.4
done
echo -e "  ${C}└──────────────────────────────────────────┴──────────┘${N}"
echo

# Upload progress
echo -e "  ${Y}── Uploading to C2 ──${N}"
echo
progress_bar "Encrypting payload" 100 "$M"
progress_bar "Uploading ${EXFIL_SIZE}" 100 "$R"
echo
echo -e "  ${G}  ✓ ${EXFIL_SIZE} exfiltrated to ${C2}${N}"
echo
sleep 2

# Third movie quote
show_movie_quote $((ART_SEED + 5))
sleep 1.5
clear

# ══════════════════════════════════════════════════════════════
# PHASE 6: LATERAL MOVEMENT + PERSISTENCE (15s)
# ══════════════════════════════════════════════════════════════

echo
echo -e "  ${M}╔══════════════════════════════════════════════════════╗${N}"
echo -e "  ${M}║${N}  ${W}LATERAL MOVEMENT & PERSISTENCE${N}                      ${M}║${N}"
echo -e "  ${M}╚══════════════════════════════════════════════════════╝${N}"
echo

# Pivot to next machine
PIVOT_IDX=$(( (ART_SEED + 1) % 8 ))
log_line "$C" "Pivoting to ${COUNCIL_HOSTS[$PIVOT_IDX]} (${COUNCIL_IPS[$PIVOT_IDX]})..."
log_line "$G" "SSH tunnel established"
log_line "$Y" "Deploying rootkit to ${COUNCIL_HOSTS[$PIVOT_IDX]}"
log_line "$G" "Persistence installed: LaunchDaemon .com.apple.update"
log_line "$D" "Cron backdoor: */5 * * * * /tmp/.b4ckd00r.sh"
log_line "$R" "Tracks cleared: history, logs, forensic artifacts"
echo

sleep 1

# ══════════════════════════════════════════════════════════════
# FINALE — Unique art + summary box
# ══════════════════════════════════════════════════════════════

clear
show_ascii_art
echo
echo -e "  ${R}╔══════════════════════════════════════════════════════╗${N}"
echo -e "  ${R}║${N}                                                      ${R}║${N}"
printf  "  ${R}║${N}   ${W}TARGET:${N}  ${G}%-44s${R}║${N}\n" "${HOST}"
printf  "  ${R}║${N}   ${W}IP:${N}      ${G}%-44s${R}║${N}\n" "${IP}"
printf  "  ${R}║${N}   ${W}GROUP:${N}   ${Y}%-44s${R}║${N}\n" "${HACKER}"
printf  "  ${R}║${N}   ${W}STATUS:${N}  ${R}%-44s${R}║${N}\n" "FULLY COMPROMISED"
printf  "  ${R}║${N}   ${W}DATA:${N}    ${Y}%-44s${R}║${N}\n" "${EXFIL_SIZE} EXFILTRATED → ${C2}"
echo -e "  ${R}║${N}                                                      ${R}║${N}"
echo -e "  ${R}╚══════════════════════════════════════════════════════╝${N}"
echo
sleep 3

# ══════════════════════════════════════════════════════════════
# MATRIX RAIN — unique charset per machine
# ══════════════════════════════════════════════════════════════

CHARSETS=(
    "01アイウエオカキクケコ@#\$%&"
    "01абвгдежзик@#\$%&"
    "01你好世界黑客入侵@#\$%&"
    "01αβγδεζηθικ@#\$%&"
    "01♠♣♥♦★☆◆◇○●@#\$%&"
    "01بتثجحخدذرز@#\$%&"
    "01가나다라마바사아자차@#\$%&"
    "01∑∏∫∂√∞≈≠±@#\$%&"
)
RAIN_CHARS="${CHARSETS[$ART_SEED]}"

echo -e "${G}"
while true; do
    line=""
    for ((i=0; i<COLS; i++)); do
        r=$((RANDOM % 4))
        if [ $r -eq 0 ]; then
            line+="$(printf '%x' $((RANDOM % 16)))"
        elif [ $r -eq 1 ]; then
            line+=" "
        elif [ $r -eq 2 ]; then
            line+="${RAIN_CHARS:$((RANDOM % ${#RAIN_CHARS})):1}"
        else
            line+="$(printf '%x' $((RANDOM % 256)))"
        fi
    done
    echo "$line"
    sleep 0.05
done
