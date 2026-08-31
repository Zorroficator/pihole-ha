#!/bin/bash
# deploy.sh — Rolls out dnsdist + monitor + VIP-bind on the Pi Zero (via Tailscale)
#
# Prerequisites on Pi Zero (one-time, manual):
#   1. /etc/telegram-notify.conf must exist (shared with the keepalived
#      notifier), format:
#          TELEGRAM_TOKEN=123456:AA...
#          TELEGRAM_CHAT_ID=-1001234567890
#      The monitor runs as the unprivileged 'dietpi' user, so the file must be
#      readable by it: either `chmod 644` or `chown root:dietpi && chmod 640`.
#   2. passwordless sudo for 'ip addr add/del' + 'arping' — see section below
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
    pihole-vip-bind.sh \
    pihole-vip.service \
    pihole_maintenance.sh \
    ../bin/telegram-send.sh \
    "${PI_HOST}:${REMOTE_DIR}/"

echo "→ Installing dnsdist.conf"
ssh "$PI_HOST" "sudo install -m 644 -o root -g root ${REMOTE_DIR}/dnsdist.conf /etc/dnsdist/dnsdist.conf"

echo "→ Installing VIP bind script"
ssh "$PI_HOST" "sudo install -m 755 -o root -g root ${REMOTE_DIR}/pihole-vip-bind.sh /usr/local/bin/pihole-vip-bind.sh"

echo "→ Installing systemd system units (VIP bind + monitor)"
ssh "$PI_HOST" "sudo install -m 644 -o root -g root ${REMOTE_DIR}/pihole-vip.service /etc/systemd/system/pihole-vip.service && \
                 sudo install -m 644 -o root -g root ${REMOTE_DIR}/pihole-monitor.service /etc/systemd/system/pihole-monitor.service && \
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
echo "1. Passwordless sudo for 'ip addr' + 'arping':"
echo "   ssh ${PI_HOST}"
echo "   sudo visudo -f /etc/sudoers.d/pihole-failover"
echo "   → ${PI_USER} ALL=(root) NOPASSWD: /sbin/ip addr add ${VIP}/32 dev ${IFACE_PI}, /sbin/ip addr del ${VIP}/32 dev ${IFACE_PI}, /usr/bin/arping -U -c 1 -I ${IFACE_PI} ${VIP}"
echo
echo "2. Set up weekly maintenance (Pi-hole update + gravity):"
echo "   ssh ${PI_HOST}"
echo "   sudo install -m 755 -o root -g root ${REMOTE_DIR}/pihole_maintenance.sh /etc/cron.weekly/pihole-maintenance"
echo "   # NO .sh in the target — run-parts ignores the file otherwise"
echo
echo "3. Enable + start VIP bind + dnsdist + monitor:"
echo "   ssh ${PI_HOST} 'sudo systemctl enable --now pihole-vip'"
echo "   ssh ${PI_HOST} 'sudo systemctl enable --now dnsdist'"
echo "   ssh ${PI_HOST} 'sudo systemctl enable --now pihole-monitor'"
echo
echo "4. Watch logs:"
echo "   ssh ${PI_HOST} 'sudo journalctl -u pihole-vip -u dnsdist -u pihole-monitor -f'"
