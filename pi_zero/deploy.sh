#!/bin/bash
# deploy.sh — Rolls out dnsdist + the keepalived stack + the failover monitor
# on the Pi Zero (via Tailscale).
#
# The Pi Zero is VRRP BACKUP (priority 100): keepalived only hands it the VIP
# if the dns-ha node fails. keepalived manages the VIP exclusively — there is
# no separate static-bind service anymore.
#
# Prerequisites on Pi Zero (one-time, manual):
#   1. dnsdist + keepalived installed (apt).
#   2. /etc/telegram-notify.conf must exist (shared with the keepalived
#      notifier), format:
#          TELEGRAM_TOKEN=123456:AA...
#          TELEGRAM_CHAT_ID=-1001234567890
#      The monitor runs as the unprivileged 'dietpi' user, so the file must be
#      readable by it: either `chmod 644` or `chown root:dietpi && chmod 640`.
set -euo pipefail

REMOTE_DIR="/home/dietpi/projects/pihole-ha/pi_zero"

# Orchestrator: reads config.env directly (not a *.tmpl). Resolve the repo root
# from $0 *before* cd'ing into pi_zero/ (the scp list below uses bare filenames).
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -f "$ROOT/config.env" ]; then
  echo "run: cp config.env.example config.env && edit it" >&2; exit 1
fi
set -a; . "$ROOT/config.env"; set +a
(cd "$ROOT" && ./render.sh)

PI_HOST="${PI_HOST:-${PI_USER}@${PIZERO_TAILSCALE_IP}}"

cd "$(dirname "$0")"

echo "→ Creating remote directory on ${PI_HOST}"
ssh "$PI_HOST" "mkdir -p ${REMOTE_DIR}"

echo "→ Copying files over"
scp dnsdist.conf \
    monitor_config.toml \
    pihole_monitor.py \
    pihole-monitor.service \
    pihole_maintenance.sh \
    ../bin/telegram-send.sh \
    ../keepalived/pi-zero.keepalived.conf \
    ../keepalived/chk_dnsdist.sh \
    ../keepalived/notify_telegram.sh \
    ../keepalived/30-pihole-ha-nonlocal-bind.conf \
    "${PI_HOST}:${REMOTE_DIR}/"

echo "→ Installing dnsdist.conf"
ssh "$PI_HOST" "sudo install -m 644 -o root -g root ${REMOTE_DIR}/dnsdist.conf /etc/dnsdist/dnsdist.conf"

echo "→ Installing keepalived stack"
ssh "$PI_HOST" "sudo install -d -m 755 -o root -g root /etc/keepalived && \
                 sudo install -m 644 -o root -g root ${REMOTE_DIR}/pi-zero.keepalived.conf /etc/keepalived/keepalived.conf && \
                 sudo install -m 755 -o root -g root ${REMOTE_DIR}/chk_dnsdist.sh /etc/keepalived/chk_dnsdist.sh && \
                 sudo install -m 700 -o root -g root ${REMOTE_DIR}/notify_telegram.sh /etc/keepalived/notify_telegram.sh"

echo "→ Installing nonlocal-bind sysctl drop-in"
ssh "$PI_HOST" "sudo install -m 644 -o root -g root ${REMOTE_DIR}/30-pihole-ha-nonlocal-bind.conf /etc/sysctl.d/30-pihole-ha-nonlocal-bind.conf"

echo "→ Installing systemd system unit (monitor) + monitor code"
ssh "$PI_HOST" "sudo install -m 644 -o root -g root ${REMOTE_DIR}/pihole-monitor.service /etc/systemd/system/pihole-monitor.service && \
                 sudo install -d -m 755 -o root -g root /usr/local/lib/pihole-ha && \
                 sudo install -m 755 -o root -g root ${REMOTE_DIR}/pihole_monitor.py /usr/local/lib/pihole-ha/pihole_monitor.py && \
                 sudo install -m 644 -o root -g root ${REMOTE_DIR}/monitor_config.toml /usr/local/lib/pihole-ha/monitor_config.toml && \
                 sudo install -m 755 -o root -g root ${REMOTE_DIR}/telegram-send.sh /usr/local/lib/pihole-ha/telegram-send.sh && \
                 sudo systemctl daemon-reload"

# Keep exactly one live copy of the monitor code + config (root-owned
# /usr/local/lib/pihole-ha/); drop the staging copies under the dietpi-writable
# REMOTE_DIR so they can't diverge.
ssh "$PI_HOST" "rm -f ${REMOTE_DIR}/pihole_monitor.py ${REMOTE_DIR}/monitor_config.toml ${REMOTE_DIR}/telegram-send.sh"

echo
echo "===== NEXT STEPS (manual) ====="
echo
echo "1. Apply the nonlocal-bind sysctl (lets dnsdist bind ${VIP}:53 while the"
echo "   node does not hold the VIP):"
echo "   ssh ${PI_HOST} 'sudo sysctl --system'"
echo "   ssh ${PI_HOST} \"ss -tulnp | grep ':53'\"   # confirm the bind"
echo
echo "2. Set the real keepalived auth_pass (identical on BOTH nodes) from your"
echo "   password store — /etc/keepalived/keepalived.conf still carries the"
echo "   VRRP_AUTH_PASS value from config.env, which is only a placeholder."
echo "   Also make sure /etc/telegram-notify.conf exists (see header)."
echo
echo "3. Set up weekly maintenance (Pi-hole update + gravity):"
echo "   ssh ${PI_HOST}"
echo "   sudo install -m 755 -o root -g root ${REMOTE_DIR}/pihole_maintenance.sh /etc/cron.weekly/pihole-maintenance"
echo "   # NO .sh in the target — run-parts ignores the file otherwise"
echo
echo "4. Enable + start keepalived + dnsdist + monitor:"
echo "   ssh ${PI_HOST} 'sudo systemctl enable --now keepalived'"
echo "   ssh ${PI_HOST} 'sudo systemctl enable --now dnsdist'"
echo "   ssh ${PI_HOST} 'sudo systemctl enable --now pihole-monitor'"
echo
echo "5. Watch logs:"
echo "   ssh ${PI_HOST} 'sudo journalctl -u keepalived -u dnsdist -u pihole-monitor -f'"
