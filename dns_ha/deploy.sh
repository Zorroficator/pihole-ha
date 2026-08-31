#!/bin/bash
# deploy.sh — Rolls out dnsdist + the keepalived stack + the nonlocal-bind
# sysctl drop-in on the dns-ha node.
#
# dns-ha is a Multipass VM running on the server host, VRRP MASTER (priority
# 150). It holds the VIP in normal operation. The VM has no direct SSH route
# from here, so every command hops through the server host:
#
#     ssh <SERVER_SSH_TARGET> "multipass exec <DNS_HA_VM_NAME> -- <cmd>"
#
# and files are piped in via `multipass exec ... -- tee`.
#
# Prerequisites inside the VM (one-time, manual):
#   1. dnsdist + keepalived installed (apt).
#   2. Passwordless sudo for the default user — standard on a stock Multipass
#      Ubuntu image; this script assumes it.
#   3. /etc/telegram-notify.conf must exist (600 root:root), shared with the
#      keepalived notifier, format:
#          TELEGRAM_TOKEN=123456:AA...
#          TELEGRAM_CHAT_ID=-1001234567890
#      See "NEXT STEPS" below.
set -euo pipefail

# Orchestrator: reads config.env directly (not a *.tmpl). Resolve the repo root
# from $0 *before* cd'ing into dns_ha/.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ ! -f "$ROOT/config.env" ]; then
  echo "run: cp config.env.example config.env && edit it" >&2; exit 1
fi
set -a; . "$ROOT/config.env"; set +a
(cd "$ROOT" && ./render.sh)

: "${SERVER_SSH_TARGET:?set SERVER_SSH_TARGET in config.env}"
: "${DNS_HA_VM_NAME:?set DNS_HA_VM_NAME in config.env}"

cd "$(dirname "$0")"

VM_STAGE="/tmp/pihole-ha-deploy"

# Run a command inside the VM (through the server host).
vm() { ssh "$SERVER_SSH_TARGET" "multipass exec ${DNS_HA_VM_NAME} -- $*"; }

# Pipe a local file into a path inside the VM.
#   vm_put <local-file> <remote-path>
vm_put() {
  ssh "$SERVER_SSH_TARGET" "multipass exec ${DNS_HA_VM_NAME} -- tee $2 >/dev/null" < "$1"
}

echo "→ Creating staging directory in ${DNS_HA_VM_NAME}"
vm "mkdir -p ${VM_STAGE}"

echo "→ Piping rendered files into ${DNS_HA_VM_NAME}"
vm_put dnsdist.conf                                   "${VM_STAGE}/dnsdist.conf"
vm_put ../keepalived/dns-ha.keepalived.conf           "${VM_STAGE}/keepalived.conf"
vm_put ../keepalived/chk_dnsdist.sh                   "${VM_STAGE}/chk_dnsdist.sh"
vm_put ../keepalived/notify_telegram.sh               "${VM_STAGE}/notify_telegram.sh"
vm_put ../keepalived/30-pihole-ha-nonlocal-bind.conf  "${VM_STAGE}/30-pihole-ha-nonlocal-bind.conf"

echo "→ Installing into place (root:root)"
# One `vm` call per command: the `multipass exec` hop passes argv, not a shell,
# so an && chain would be split by the *server's* shell and only the first
# command would run inside the VM.
vm "sudo install -m 644 -o root -g root ${VM_STAGE}/dnsdist.conf /etc/dnsdist/dnsdist.conf"
vm "sudo install -d -m 755 -o root -g root /etc/keepalived"
vm "sudo install -m 644 -o root -g root ${VM_STAGE}/keepalived.conf /etc/keepalived/keepalived.conf"
vm "sudo install -m 755 -o root -g root ${VM_STAGE}/chk_dnsdist.sh /etc/keepalived/chk_dnsdist.sh"
vm "sudo install -m 700 -o root -g root ${VM_STAGE}/notify_telegram.sh /etc/keepalived/notify_telegram.sh"
vm "sudo install -m 644 -o root -g root ${VM_STAGE}/30-pihole-ha-nonlocal-bind.conf /etc/sysctl.d/30-pihole-ha-nonlocal-bind.conf"

echo "→ Removing staging copies"
vm "rm -f ${VM_STAGE}/dnsdist.conf ${VM_STAGE}/keepalived.conf ${VM_STAGE}/chk_dnsdist.sh ${VM_STAGE}/notify_telegram.sh ${VM_STAGE}/30-pihole-ha-nonlocal-bind.conf"
vm "rmdir ${VM_STAGE} 2>/dev/null || true"

echo
echo "===== NEXT STEPS (manual, inside the VM) ====="
echo
echo "  ssh ${SERVER_SSH_TARGET} \"multipass shell ${DNS_HA_VM_NAME}\""
echo
echo "1. Apply the nonlocal-bind sysctl:"
echo "   sudo sysctl --system"
echo "   # then confirm dnsdist can bind the VIP even without holding it:"
echo "   ss -tulnp | grep ':53'"
echo
echo "2. Set the real keepalived auth_pass (identical on BOTH nodes) from your"
echo "   password store — /etc/keepalived/keepalived.conf still carries the"
echo "   VRRP_AUTH_PASS value from config.env, which is only a placeholder."
echo
echo "3. /etc/telegram-notify.conf must exist (600 root:root) with:"
echo "       TELEGRAM_TOKEN=..."
echo "       TELEGRAM_CHAT_ID=..."
echo
echo "4. Enable + start the services:"
echo "   sudo systemctl enable --now dnsdist keepalived"
echo
echo "5. Watch logs:"
echo "   journalctl -u dnsdist -u keepalived -f"
