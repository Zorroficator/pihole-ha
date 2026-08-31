#!/bin/bash
# deploy_monitoring.sh — Rolls out the two monitoring building blocks:
#
#   1. pi_health_logger.sh  → the Pi Zero    (persistent crash forensics)
#   2. pihole_heartbeat.sh  → the server     (external DNS heartbeat)
#
# Needs NO sudo: Pi scripts live in ~dietpi, cron via the dietpi user's
# crontab; on the server a user LaunchAgent.
set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"

# Orchestrator: reads config.env directly (not a *.tmpl), then renders the
# config/template files before shipping them.
if [ ! -f "$ROOT/config.env" ]; then
  echo "run: cp config.env.example config.env && edit it" >&2; exit 1
fi
set -a; . "$ROOT/config.env"; set +a
./render.sh

SERVER="${SERVER:-$SERVER_IP}"
PIZERO="${PIZERO:-$PIZERO_IP}"

echo "═══ 1) Pi Zero: pi_health_logger.sh ═══"
ssh "dietpi@$PIZERO" "mkdir -p ~/scripts ~/data/pi_health"
scp pi_zero/pi_health_logger.sh "dietpi@$PIZERO:~/scripts/"
ssh "dietpi@$PIZERO" "chmod +x ~/scripts/pi_health_logger.sh"

echo "→ Adding to crontab (backup at ~/data/pi_health/crontab.bak-s1)"
ssh "dietpi@$PIZERO" '
  crontab -l > ~/data/pi_health/crontab.bak-s1 2>/dev/null || true
  ( crontab -l 2>/dev/null | grep -v "pi_health_logger.sh"
    echo "@reboot sleep 60 && /home/dietpi/scripts/pi_health_logger.sh boot"
    echo "*/20 * * * * /home/dietpi/scripts/pi_health_logger.sh tick"
  ) | crontab -
  echo "→ Crontab entries:"; crontab -l | grep "pi_health_logger.sh"
'

echo "→ Writing a boot record right away"
ssh "dietpi@$PIZERO" '~/scripts/pi_health_logger.sh boot && tail -1 ~/data/pi_health/health.jsonl'

echo
echo "═══ 2) Server: pihole_heartbeat.sh ═══"
ssh "$SERVER" "mkdir -p ~/projects/pihole-ha/server ~/data/pihole_heartbeat ~/.config/pihole-ha"
scp server/pihole_heartbeat.sh server/local.pihole-heartbeat.plist bin/telegram-send.sh \
    "$SERVER:~/projects/pihole-ha/server/"

echo "→ Installing LaunchAgent (user, no sudo)"
ssh "$SERVER" '
  chmod +x ~/projects/pihole-ha/server/telegram-send.sh
  mkdir -p ~/Library/LaunchAgents
  sed "s|/Users/YOUR_USERNAME|$HOME|g" \
      ~/projects/pihole-ha/server/local.pihole-heartbeat.plist \
      > ~/Library/LaunchAgents/local.pihole-heartbeat.plist
  launchctl bootout   gui/$(id -u)/local.pihole-heartbeat 2>/dev/null || true
  launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.pihole-heartbeat.plist
  if grep -q YOUR_USERNAME ~/Library/LaunchAgents/local.pihole-heartbeat.plist; then
    echo "✗ plist still has YOUR_USERNAME placeholder — aborting" >&2; exit 1
  fi
  echo "→ Test run:"; bash ~/projects/pihole-ha/server/pihole_heartbeat.sh
  echo "→ Heartbeat log:"; tail -2 ~/data/pihole_heartbeat/heartbeat.log
  echo "→ LaunchAgent:"; launchctl list | grep pihole-heartbeat || true
'

echo
echo "✓ Done. Check later:"
echo "  Pi:     ssh dietpi@$PIZERO 'tail ~/data/pi_health/health.jsonl'"
echo "  Server: ssh $SERVER 'tail ~/data/pihole_heartbeat/heartbeat.log'"
