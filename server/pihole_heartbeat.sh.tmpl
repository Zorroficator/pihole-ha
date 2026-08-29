#!/bin/bash
# pihole_heartbeat.sh — External heartbeat for the home network DNS.
#
# Runs on the server every 5 min (LaunchAgent local.pihole-heartbeat).
# Checks FUNCTIONALLY whether clients can still resolve DNS via the
# VIP <VIP>. The failover monitor runs ON the Pi Zero and logically
# can't report itself as dead — this heartbeat closes that gap
# from the outside.
#
# Behavior:
#   - fail-only: alert only after FAIL_THRESHOLD consecutive failures
#   - recovery notification when DNS comes back
#   - weekly Sunday heartbeat (~10:00) as a sign of life
#
# Manual test:  bash pihole_heartbeat.sh

set -u
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

VIP="<VIP>"
PIZERO="<PIZERO_IP>"
SERVER_PIHOLE="<SERVER_IP>"
TEST_DOMAIN="cloudflare.com"
FAIL_THRESHOLD=3                 # 3 x 5 min = 15 min until alert

STATE_DIR="$HOME/data/pihole_heartbeat"
mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/heartbeat.log"
STATE="$STATE_DIR/state"         # format: "<consecutive_fails> <up|down>"

stamp=$(date '+%Y-%m-%d %H:%M')
log() { echo "$(date '+%F %T') $1" >> "$LOG"; }

# ── Load state ───────────────────────────────────────────────────────────────
fails=0
status="up"
if [[ -r "$STATE" ]]; then
    read -r fails status _ < "$STATE" 2>/dev/null || { fails=0; status="up"; }
fi
[[ "$fails" =~ ^[0-9]+$ ]] || fails=0
[[ "$status" == "up" || "$status" == "down" ]] || status="up"

# ── Telegram via mod_Telegram_Info (msg via ENV, avoids escaping) ───────────
send_telegram() {
    export HB_MSG="$1" HB_LEVEL="$2"
    python3 - <<'PY'
import os, sys
sys.path.insert(0, os.path.expanduser("~/projects/mod_Telegram_Info"))
try:
    import mod_telegram
    mod_telegram.send(os.environ["HB_MSG"], level=os.environ["HB_LEVEL"])
except Exception as e:
    print(f"Telegram send failed: {e}", file=sys.stderr)
    sys.exit(1)
PY
}

# ── Functional DNS check via the VIP ─────────────────────────────────────────
answer=$(dig +short +time=3 +tries=1 "@$VIP" "$TEST_DOMAIN" A 2>/dev/null \
         | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)

if [[ -n "$answer" ]]; then
    # ── DNS OK ──────────────────────────────────────────────────────────────
    log "OK — DNS via $VIP -> $answer"
    if [[ "$status" == "down" ]]; then
        send_telegram "✅ Home network DNS reachable again — $stamp"$'\n'"VIP $VIP resolves again ($answer)." "info"
        log "RECOVERY reported"
    fi
    echo "0 up" > "$STATE"
else
    # ── DNS FAIL — classify ────────────────────────────────────────────────
    fails=$(( fails + 1 ))
    if ping -c1 -t2 "$PIZERO" >/dev/null 2>&1; then pi_state="Pi Zero pingable"
    else pi_state="Pi Zero NOT pingable"; fi
    srv=$(dig +short +time=3 +tries=1 "@$SERVER_PIHOLE" "$TEST_DOMAIN" A 2>/dev/null \
          | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
    if [[ -n "$srv" ]]; then srv_state="server Pi-hole .21 OK"
    else srv_state="server Pi-hole .21 down"; fi
    log "FAIL $fails/$FAIL_THRESHOLD — $pi_state; $srv_state"

    if (( fails >= FAIL_THRESHOLD )) && [[ "$status" == "up" ]]; then
        msg="🔴 Home network DNS down — $stamp"$'\n\n'
        msg+="VIP $VIP hasn't answered ${fails}x in a row."$'\n'
        msg+="• $pi_state"$'\n'
        msg+="• $srv_state"$'\n\n'
        if [[ -n "$srv" ]]; then
            msg+="Immediate fix: FritzBox → set local DNS server to $SERVER_PIHOLE."
        else
            msg+="Both Pi-holes gone. Immediate fix: set FritzBox DNS to <ROUTER_IP>."
        fi
        send_telegram "$msg" "warning"
        echo "$fails down" > "$STATE"
        log "ALERT sent"
    else
        echo "$fails $status" > "$STATE"
    fi
fi

# ── Weekly Sunday heartbeat (Sun ~10:00, once a week) ────────────────────────
if [[ "$(date +%u)" == "7" && "$(date +%H)" == "10" ]]; then
    hb_marker="$STATE_DIR/weekly_$(date +%G%V).done"
    if [[ ! -f "$hb_marker" ]]; then
        if [[ -n "$answer" ]]; then
            send_telegram "🟢 Pi-hole heartbeat OK — $stamp"$'\n'"VIP $VIP resolves ($answer)." "info"
        fi
        touch "$hb_marker"
        find "$STATE_DIR" -maxdepth 1 -name 'weekly_*.done' -mtime +21 -delete 2>/dev/null
    fi
fi

exit 0
