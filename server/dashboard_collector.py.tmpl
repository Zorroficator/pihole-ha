#!/usr/bin/env python3
"""dashboard_collector.py — Pi-hole failover status via dnsdist API + monitor state.

Runs on the server host (the Docker host, <SERVER_IP>) as a LaunchAgent/cron
every 60 s. Writes data.json + history.json in the schema app.js expects.

Data sources:
  Pi Zero (one SSH call over Tailscale):
    - dnsdist HTTP API :8083  → backend states + latency
    - monitor_state.json      → role (primary_up/fallback_up) + recent events
    - history.jsonl           → event log
    - bot_state.json          → Telegram bot last_contact_s
    - audit.log               → Telegram bot audit_count_30d
    - systemctl is-active     → Telegram bot online status + dnsdist uptime
  Server host (local):
    - ~/data/pihole-ha/update.log → last update run
"""
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone, timedelta
from pathlib import Path

PIZERO_TAILSCALE = "<PIZERO_TAILSCALE_IP>"
SSH_TIMEOUT = 10

OUTPUT      = Path.home() / "www" / "dash_pihole" / "data.json"
HISTORY_OUT = Path.home() / "www" / "dash_pihole" / "history.json"
UPDATE_LOG  = Path.home() / "data" / "pihole-ha" / "update.log"
STATE_DIR   = Path.home() / "data" / "pihole-ha"
ALERT_FILE  = STATE_DIR / "alert_state.json"
TELEGRAM    = Path.home() / "scripts" / "telegram_notify.sh"

PRIMARY_DOWN_THRESHOLD = 3  # cycles × 60 s → Telegram warning


# ── Remote script (runs on the Pi Zero via SSH) ──────────────────────────────

_REMOTE = r"""
import json, subprocess, time
from datetime import datetime, timezone, timedelta
from pathlib import Path

out = {}

# dnsdist API
try:
    import urllib.request
    with urllib.request.urlopen(
        "http://127.0.0.1:8083/api/v1/servers/localhost", timeout=3
    ) as r:
        api = json.loads(r.read())
    backends = {}
    for s in api.get("servers", []):
        backends[s["name"]] = {
            "state":   s.get("state", "down"),
            "latency": s.get("latency"),
        }
    out["dnsdist"] = {"ok": True, "backends": backends}
except Exception as e:
    out["dnsdist"] = {"ok": False, "error": str(e)[:200]}

# dnsdist uptime via systemd
try:
    r = subprocess.run(
        ["systemctl", "show", "dnsdist", "--property=ActiveEnterTimestamp"],
        capture_output=True, text=True, timeout=3,
    )
    raw = r.stdout.strip().split("=", 1)[-1].strip()
    # Format: "Weekday YYYY-MM-DD HH:MM:SS TZ" (e.g. "Sat 2026-05-02 13:59:26 CEST")
    parts = raw.split()
    if len(parts) >= 3:
        dt = datetime.strptime(f"{parts[1]} {parts[2]}", "%Y-%m-%d %H:%M:%S")
        tz_offsets = {"UTC": 0, "CET": 1, "CEST": 2}
        offset_h = tz_offsets.get(parts[3] if len(parts) > 3 else "UTC", 0)
        tz = timezone(timedelta(hours=offset_h))
        out["dnsdist_started_ts"] = dt.replace(tzinfo=tz).isoformat()
    else:
        out["dnsdist_started_ts"] = None
except Exception:
    out["dnsdist_started_ts"] = None

# monitor state
try:
    ms = json.loads(
        Path("/home/dietpi/data/pihole_failover/monitor_state.json").read_text()
    )
    out["monitor_state"] = ms
except Exception:
    out["monitor_state"] = None

# history (last 20 events)
try:
    lines = Path("/home/dietpi/data/pihole_failover/history.jsonl").read_text().splitlines()
    out["history"] = [json.loads(l) for l in lines if l.strip()][-20:]
except Exception:
    out["history"] = []

# Telegram bot: service status + last-contact + audit
try:
    r = subprocess.run(
        ["systemctl", "--user", "is-active", "telegram_bot"],
        capture_output=True, text=True, timeout=3,
    )
    out["telegram_bot_active"] = r.stdout.strip() == "active"
except Exception:
    out["telegram_bot_active"] = False

try:
    bs = json.loads(Path("/home/dietpi/data/telegram_bot/bot_state.json").read_text())
    successes = bs.get("last_success") or {}
    out["telegram_bot_last_ts"] = max(successes.values()) if successes else None
except Exception:
    out["telegram_bot_last_ts"] = None

try:
    cutoff = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
    count = sum(
        1 for line in Path("/home/dietpi/data/telegram_bot/audit.log").read_text().splitlines()
        if line.strip() and line.split()[0] >= cutoff
    )
    out["telegram_bot_audit_30d"] = count
except Exception:
    out["telegram_bot_audit_30d"] = 0

out["collected_at"] = time.time()
print(json.dumps(out))
"""


def collect_pizero() -> dict | None:
    """Single SSH call collects all Pi Zero data (script piped via stdin)."""
    try:
        result = subprocess.run(
            [
                "ssh", "-o", "BatchMode=yes",
                "-o", f"ConnectTimeout={SSH_TIMEOUT}",
                f"dietpi@{PIZERO_TAILSCALE}",
                "python3",
            ],
            input=_REMOTE,
            capture_output=True, text=True, timeout=SSH_TIMEOUT + 5,
        )
        if result.returncode != 0:
            return None
        return json.loads(result.stdout)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError):
        return None


# ── Update log ───────────────────────────────────────────────────────────────

def parse_update_log() -> dict:
    if not UPDATE_LOG.exists():
        return {}
    try:
        text = UPDATE_LOG.read_text(errors="replace")
        matches = re.findall(
            r"===\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+update\s+(\w+)\s+===",
            text,
        )
        if not matches:
            return {}
        ts_str, result = matches[-1]
        dt = datetime.strptime(ts_str, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
        return {"last_run_ts": dt.isoformat(), "last_result": result}
    except (OSError, ValueError):
        return {}


# ── Alert ────────────────────────────────────────────────────────────────────

def _read_alert() -> dict:
    try:
        return json.loads(ALERT_FILE.read_text())
    except (OSError, json.JSONDecodeError):
        return {"down_cycles": 0, "alerted": False}


def _write_alert(state: dict) -> None:
    try:
        ALERT_FILE.write_text(json.dumps(state))
    except OSError:
        pass


def _telegram(level: str, text: str) -> None:
    try:
        subprocess.run([str(TELEGRAM), text, level], capture_output=True, timeout=10)
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass


def handle_alert(role: str) -> None:
    state = _read_alert()
    if role == "primary_down":
        state["down_cycles"] = state.get("down_cycles", 0) + 1
        if state["down_cycles"] >= PRIMARY_DOWN_THRESHOLD and not state.get("alerted"):
            _telegram("warning", "⚠️ Pi-hole primary (server) down — fallback active")
            state["alerted"] = True
    elif role == "both_down":
        if not state.get("alerted"):
            _telegram("warning", "❌ Pi-hole both backends down — DNS offline")
            state["alerted"] = True
    else:
        if state.get("alerted"):
            _telegram("info", "✅ Pi-hole primary reachable again — back to normal")
        state = {"down_cycles": 0, "alerted": False}
    _write_alert(state)


# ── Schema assembly ──────────────────────────────────────────────────────────

def derive_role(monitor_state: dict | None, backends: dict | None) -> tuple[str, str | None]:
    if monitor_state:
        p_up = monitor_state.get("primary_up", True)
        f_up = monitor_state.get("fallback_up", True)
        if p_up and f_up:
            role = "normal"
        elif not p_up and f_up:
            role = "primary_down"
        elif p_up and not f_up:
            role = "fallback_down"
        else:
            role = "both_down"
        ts = None
        raw = monitor_state.get("last_primary_down")
        if raw:
            try:
                dt = datetime.strptime(raw, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
                ts = dt.isoformat()
            except ValueError:
                pass
        return role, ts

    # Fallback: derive directly from dnsdist backends
    if backends:
        p = (backends.get("server-pihole") or {}).get("state", "")
        f = (backends.get("local-pihole")  or {}).get("state", "")
        if p == "up" and f == "up":
            return "normal", None
        if p != "up" and f == "up":
            return "primary_down", None
        if p == "up" and f != "up":
            return "fallback_down", None
        return "both_down", None

    return "unknown", None


def assemble(pizero: dict | None) -> dict:
    now_ts = datetime.now(timezone.utc).isoformat()

    # dnsdist
    dn_raw     = (pizero or {}).get("dnsdist", {})
    backends   = dn_raw.get("backends", {}) if dn_raw.get("ok") else {}
    started_ts = (pizero or {}).get("dnsdist_started_ts")

    uptime_s = None
    if started_ts:
        try:
            started  = datetime.fromisoformat(started_ts)
            uptime_s = int((datetime.now(timezone.utc) - started).total_seconds())
        except ValueError:
            pass

    def _rt(b: dict) -> float | None:
        lat = b.get("latency")
        return round(lat, 1) if lat is not None else None

    if dn_raw.get("ok"):
        prim = backends.get("server-pihole", {})
        fall = backends.get("local-pihole",  {})
        dnsdist = {
            "state":    "listening",
            "uptime_s": uptime_s,
            "primary":  {"state": prim.get("state", "down"), "rt_ms": _rt(prim)},
            "fallback": {"state": fall.get("state", "down"), "rt_ms": _rt(fall)},
        }
    else:
        dnsdist = {
            "state": "down", "uptime_s": None,
            "primary":  {"state": "down", "rt_ms": None},
            "fallback": {"state": "down", "rt_ms": None},
        }

    # monitor
    monitor_state = (pizero or {}).get("monitor_state")
    role, last_takeover_ts = derive_role(monitor_state, backends or None)
    monitor = {"role": role, "last_takeover_ts": last_takeover_ts}

    # telegram bot
    if pizero:
        last_ts = pizero.get("telegram_bot_last_ts")
        bot = {
            "state":           "online" if pizero.get("telegram_bot_active") else "offline",
            "last_contact_s":  int(time.time() - last_ts) if last_ts else None,
            "audit_count_30d": pizero.get("telegram_bot_audit_30d", 0),
        }
    else:
        bot = {"state": "offline", "last_contact_s": None, "audit_count_30d": None}

    # update
    upd = parse_update_log()
    update = {
        "last_run_ts":     upd.get("last_run_ts"),
        "last_result":     upd.get("last_result", "unknown"),
        "last_duration_s": None,
    }

    handle_alert(role)

    return {
        "ts":      now_ts,
        "dnsdist": dnsdist,
        "monitor": monitor,
        "bot": bot,
        "update":  update,
    }


# ── Main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    STATE_DIR.mkdir(parents=True, exist_ok=True)

    pizero = collect_pizero()
    data   = assemble(pizero)

    tmp = OUTPUT.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2))
    os.replace(tmp, OUTPUT)

    history = (pizero or {}).get("history", [])
    tmp_h = HISTORY_OUT.with_suffix(".json.tmp")
    tmp_h.write_text(json.dumps(history, indent=2))
    os.replace(tmp_h, HISTORY_OUT)

    return 0


if __name__ == "__main__":
    sys.exit(main())
