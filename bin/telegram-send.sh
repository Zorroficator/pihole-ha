#!/usr/bin/env bash
# telegram-send.sh — the single Telegram sender every pihole-ha component uses.
#
# Usage:  telegram-send.sh <text> [level]
#   <text>   message body (callers already include their own emoji); may be
#            multi-line.
#   [level]  optional context: info | warning | error   (default: info).
#            Kept for a uniform call signature and for future log/routing use;
#            the message text is passed through verbatim (callers prefix their
#            own severity marker), and the Bot API call itself takes just
#            chat_id + text.
#
# Credentials come from a conf file that is NOT in this repo:
#   CONF path  = ${PIHOLE_HA_TG_CONF:-/etc/telegram-notify.conf}
#   CONF format= a shell file with two assignments, mode 600 (or at least
#                readable by the service user):
#                   TELEGRAM_TOKEN=123456:AA...
#                   TELEGRAM_CHAT_ID=-1001234567890
#   This is the same file keepalived/notify_telegram.sh sources as
#   /etc/telegram-notify.conf.
#
# Fire-and-forget: a missing conf or a failed delivery logs to stderr and
# exits 0 so callers never crash-loop over a notification problem. The only
# non-zero exit is a genuine usage error (no message argument at all).
#
# The bot token is never passed as a command-line argument (it would show up
# in `ps`); it only ever appears in the URL line of a `curl --config -` heredoc.
# chat_id and the (possibly multi-line) message text go through --data-urlencode
# flags instead — `curl --config` parses line by line, so a literal newline in
# a config value would break the parse.
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "usage: telegram-send.sh <text> [info|warning|error]" >&2
    exit 2
fi

MSG="$1"
LEVEL="${2:-info}"
CONF="${PIHOLE_HA_TG_CONF:-/etc/telegram-notify.conf}"

if [[ ! -r "$CONF" ]]; then
    echo "telegram-send: conf $CONF not readable — alert dropped: $1" >&2
    exit 0
fi

# shellcheck disable=SC1090
. "$CONF"

if [[ -z "${TELEGRAM_TOKEN:-}" || -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    echo "telegram-send: conf $CONF has no TELEGRAM_TOKEN/TELEGRAM_CHAT_ID — alert dropped: $1" >&2
    exit 0
fi

if ! curl -fsS -m 10 \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${MSG}" \
        --config - >/dev/null 2>&1 <<CURLCFG
url = "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage"
CURLCFG
then
    echo "telegram-send: delivery failed — alert dropped: $1" >&2
fi

exit 0
