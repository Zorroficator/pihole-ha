#!/bin/bash
# pi_health_logger.sh — Persistent crash forensics for the Pi Zero.
#
# Problem: DietPi keeps /var/log + systemd journal in RAM (tmpfs). On every
# reboot — especially an unclean one — ALL logs are gone. After a crash
# there is therefore no trace of why the Pi went down.
#
# Solution: This script periodically writes a compact health record
# to ~/data/pi_health/health.jsonl. ~/data lives on the SD card and
# survives reboots. On anomalies (undervoltage, kernel errors) an
# additional dmesg snapshot is saved.
#
# Usage:
#   pi_health_logger.sh boot   — once at boot (marks boot, checks whether
#                                the previous boot was unclean, dmesg snapshot)
#   pi_health_logger.sh tick   — periodically via cron (every 20 min)
#
# Analysis after an outage:
#   tail -n 30 ~/data/pi_health/health.jsonl
#   ls -lt    ~/data/pi_health/dmesg_*.txt

set -u

DATA_DIR="$HOME/data/pi_health"
LOG="$DATA_DIR/health.jsonl"
MAXLINES=4000           # ~ 8 weeks of 20-min ticks, then truncate to half
MAX_SNAPSHOTS=10
mkdir -p "$DATA_DIR"

MODE="${1:-tick}"
TS="$(date '+%Y-%m-%dT%H:%M:%S%z')"
UP_S="$(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0)"

# ── Memory (kB -> MB) ────────────────────────────────────────────────────────
MEM_TOTAL="$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null)"
MEM_AVAIL="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null)"
[[ "$MEM_TOTAL" =~ ^[0-9]+$ ]] || MEM_TOTAL=0
[[ "$MEM_AVAIL" =~ ^[0-9]+$ ]] || MEM_AVAIL=0
MEM_TOTAL_MB=$(( MEM_TOTAL / 1024 ))
MEM_AVAIL_MB=$(( MEM_AVAIL / 1024 ))

# ── Load / temperature / disk ────────────────────────────────────────────────
LOAD="$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)"
[[ "$LOAD" =~ ^[0-9]+\.[0-9]+$ ]] || LOAD=0

if [[ -r /sys/class/thermal/thermal_zone0/temp ]]; then
    TEMP=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
else
    TEMP="null"
fi

DISK_PCT="$(df -P / 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}')"
[[ "$DISK_PCT" =~ ^[0-9]+$ ]] || DISK_PCT=0

# ── Evaluate dmesg ───────────────────────────────────────────────────────────
# The RPi kernel reports voltage issues as "Under-voltage detected" in dmesg.
UV_COUNT="$(dmesg 2>/dev/null | grep -ci 'under-voltage')"
[[ "$UV_COUNT" =~ ^[0-9]+$ ]] || UV_COUNT=0
ERR_COUNT="$(dmesg 2>/dev/null | grep -ciE 'ext4-fs error|i/o error|oom-kill|out of memory|kernel panic|hung task|mmc0: error')"
[[ "$ERR_COUNT" =~ ^[0-9]+$ ]] || ERR_COUNT=0

EVENT="tick"
EXTRA=""
SNAPSHOT_NOW=false

if [[ "$MODE" == "boot" ]]; then
    EVENT="boot"
    SNAPSHOT_NOW=true   # boot dmesg is always valuable
    # Was the previous boot unclean? EXT4 journal recovery is the proof.
    if dmesg 2>/dev/null | grep -qi 'recovery required'; then
        EXTRA=',"prev_boot":"unclean"'
    else
        EXTRA=',"prev_boot":"clean"'
    fi
fi

# Append record
printf '{"ts":"%s","event":"%s","uptime_s":%s,"load":%s,"mem_avail_mb":%s,"mem_total_mb":%s,"temp_c":%s,"disk_pct":%s,"undervolt_msgs":%s,"crit_msgs":%s%s}\n' \
    "$TS" "$EVENT" "$UP_S" "$LOAD" "$MEM_AVAIL_MB" "$MEM_TOTAL_MB" "$TEMP" "$DISK_PCT" "$UV_COUNT" "$ERR_COUNT" "$EXTRA" \
    >> "$LOG"

# ── dmesg snapshot on anomalies (max once/hour, except at boot) ────────────
if (( UV_COUNT > 0 || ERR_COUNT > 0 )); then
    if [[ -z "$(find "$DATA_DIR" -maxdepth 1 -name 'dmesg_*.txt' -mmin -60 2>/dev/null)" ]]; then
        SNAPSHOT_NOW=true
    fi
fi
if $SNAPSHOT_NOW; then
    dmesg 2>/dev/null > "$DATA_DIR/dmesg_$(date +%Y%m%d_%H%M%S).txt"
    # keep only the most recent MAX_SNAPSHOTS
    ls -1t "$DATA_DIR"/dmesg_*.txt 2>/dev/null | tail -n +$(( MAX_SNAPSHOTS + 1 )) \
        | while read -r f; do rm -f "$f"; done
fi

# ── Rotate the jsonl ─────────────────────────────────────────────────────────
LINES="$(wc -l < "$LOG" 2>/dev/null || echo 0)"
if (( LINES > MAXLINES )); then
    tail -n $(( MAXLINES / 2 )) "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi

exit 0
