#!/bin/bash
# pihole-maintenance — weekly Pi-hole maintenance on the Pi Zero.
#
# Installed as /etc/cron.weekly/pihole-maintenance → runs via anacron.
# This means a missed run (Pi was offline) is caught up after the next boot —
# exactly the catch-up capability a plain cron.d job doesn't have.
#
# Source in the repo: pihole-ha/pi_zero/pihole_maintenance.sh
# Deployment:
#   scp pi_zero/pihole_maintenance.sh dietpi@<pi>:/tmp/
#   sudo install -m 755 -o root -g root /tmp/pihole_maintenance.sh \
#        /etc/cron.weekly/pihole-maintenance      # NO .sh — run-parts ignores it otherwise
#
# Does weekly:
#   1. pihole -up           — update Pi-hole Core/Web/FTL to the latest version
#   2. pihole updateGravity — rebuild blocklists
# Fail-only Telegram via mod_telegram wrapper; details in the log.
set -u
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

LOG_DIR="/var/log/pihole-ha"
LOG="$LOG_DIR/pihole-maintenance.log"
TG="/home/dietpi/scripts/telegram_notify.sh"
mkdir -p "$LOG_DIR"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

notify_fail() {
    # Best-effort: run wrapper as dietpi (credential file must be resolvable for that user)
    [[ -x "$TG" ]] && runuser -u dietpi -- "$TG" "Pi Zero pihole-maintenance: $1" error >/dev/null 2>&1 || true
}

log "════ pihole-maintenance start ════"
rc=0

# 1) Update Pi-hole Core/Web/FTL ──────────────────────────────────────────────
log "→ pihole -up"
pihole -up >> "$LOG" 2>&1
up_rc=$?
if (( up_rc == 0 )); then
    log "  pihole -up: OK"
else
    log "  pihole -up: FAILED (exit $up_rc)"
    notify_fail "pihole -up failed (exit $up_rc)"
    rc=1
fi

# 2) Rebuild gravity / blocklists ─────────────────────────────────────────────
log "→ pihole updateGravity"
pihole updateGravity >> "$LOG" 2>&1
gr_rc=$?
if (( gr_rc == 0 )); then
    log "  updateGravity: OK"
else
    log "  updateGravity: FAILED (exit $gr_rc)"
    notify_fail "updateGravity failed (exit $gr_rc)"
    rc=1
fi

log "════ pihole-maintenance end (rc=$rc) ════"

# Limit log to spare the SD card
if [[ -f "$LOG" ]] && (( $(wc -l < "$LOG" 2>/dev/null || echo 0) > 2000 )); then
    tail -n 1000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

exit $rc
