"use strict";

/* =================================================================
   Pi-hole Failover Dashboard — App Entry (IIFE)
   ================================================================= */

(function () {
  // ── Build-Hash-Ausgabe in der Console, hilft beim Live-Test ──
  const buildAttr = document.documentElement.getAttribute("data-build") || "dev";
  const hashAttr  = document.documentElement.getAttribute("data-hash")  || "–";
  // eslint-disable-next-line no-console
  console.info(`[pihole-ha] dashboard build=${buildAttr} hash=${hashAttr}`);

  // ── i18n Dictionary ───────────────────────────────────────────
  // DE: durchgehend deutsch. EN: durchgehend englisch.
  // Proper nouns and technical terms (dnsdist, systemd, primary, fallback)
  // bleiben in beiden Sprachen gleich — sie sind Teil des Produkts.
  const I18N = {
    de: {
      skip_to_main:    "Zum Inhalt springen",

      app_title:       "Pi-hole Failover",
      app_sub:         "dnsdist · Failover · Live",

      sb_pizero:       "Pi Zero · dnsdist",
      sb_primary:      "Primary · Server",
      sb_fallback:     "Fallback · Pi Zero FTL",
      sb_bot:      "Telegram Bot",
      sb_update:       "Update",

      section_cards:    "Komponenten",
      section_recovery: "Recovery · Notfall-Reboot",
      section_events:   "Ereignisse",

      card_clients_num:   "Karte 1",
      card_pizero_num:    "Karte 2",
      card_primary_num:   "Karte 3",
      card_fallback_num:  "Karte 4",
      card_bot_num:   "Karte 5",
      card_update_num:    "Karte 6",

      card_clients_title:  "Clients & DHCP",
      card_pizero_title:   "Pi Zero · dnsdist",
      card_primary_title:  "Primary · Server",
      card_fallback_title: "Fallback · Pi Zero FTL",
      card_bot_title:  "Reboot-Absicherung · Telegram-Bot",
      card_update_title:   "Wöchentliches Update",

      card_clients_dns_ip:      "DNS-IP",
      card_clients_dhcp_range:  "DHCP-Bereich",
      card_clients_router:      "Router",
      card_clients_reservation: "Reservierung",

      card_pizero_host:    "Host",
      card_pizero_vip:     "VRRP-Rolle",
      val_pizero_vrrp:     "BACKUP · Prio 100",
      card_pizero_uptime:  "Laufzeit",
      card_pizero_policy:  "Policy",
      card_pizero_systemd: "systemd",
      hint_pizero_vip:     "übernimmt die VIP <VIP> nur bei Ausfall der dns-ha-VM · Admin-UI immer auf der Pi-Zero-IP",

      card_primary_host:      "Host",
      card_primary_weight:    "Reihenfolge",
      card_primary_health:    "Health",
      card_primary_container: "Container",
      card_primary_rt:        "Letzte RT",
      card_primary_webui:     "Web-UI",
      hint_primary_webui:     "zeigt echte Client-Queries",

      card_fallback_host:     "Host",
      card_fallback_weight:   "Reihenfolge",
      card_fallback_health:   "Health",
      card_fallback_ftl:      "Pi-hole-FTL",
      card_fallback_takeover: "Letzter Takeover",
      card_fallback_webui:    "Web-UI",
      hint_fallback_webui:    "im Normalbetrieb nur Healthchecks",

      card_bot_handle:   "Bot",
      card_bot_service:  "Dienst",
      card_bot_contact:  "Letzter Kontakt",
      card_bot_cooldown: "Sperrzeit",
      card_bot_pin:      "PIN",
      card_bot_audit:    "Audit-Zähler",

      card_update_last:   "Letzter Lauf",
      card_update_method: "Methode",
      card_update_alert:  "Alert",
      card_update_next:   "Nächster Lauf",

      flow_f1_sub:   "Client-Anfragen",
      flow_health:   "health-check · 5 s · Primary 4 Fehler = down",
      flow_caption:  "FritzBox-DHCP verteilt die VIP als DNS → dnsdist hinter der VIP (per keepalived normal auf der dns-ha-VM) routet auf den Primary solange gesund, sonst auf den Fallback",
      node_clients:  "Clients · FritzBox",
      node_primary:  "Primary · Server",
      node_fallback: "Fallback · Pi Zero FTL",

      hero_normal:        "Normalbetrieb — Primary liefert, Fallback in Bereitschaft",
      hero_primary_down:  "⚠ PRIMARY AUSGEFALLEN — Fallback übernimmt",
      hero_fallback_down: "Primary liefert — Fallback-Bereitschaft gestört",
      hero_both_down:     "❌ BEIDE BACKENDS AUSGEFALLEN — DNS offline",
      hero_stale:         "⚠ Collector meldet keine frischen Daten",
      hero_unknown:       "Status unbekannt",
      since:              "seit",

      state_online_ready:   "online · bereit",
      state_offline:        "offline",
      recovery_last_contact:"letzter Kontakt · {age}",
      recovery_emergency:   "Notfall-Reboot",
      recovery_reboot:      "-Reboot",
      recovery_via:         "via sudo shutdown -r now",

      events_empty:         "Noch keine Ereignisse — System läuft frisch.",

      alert_title:          "⚠ PRIMARY AUSGEFALLEN",
      alert_sub_template:   "Fallback liefert · seit {age}",

      // Badges (technische Uppercase-Zustände — bewusst gleich in DE/EN)
      badge_listening: "LISTENING",
      badge_up:        "UP",
      badge_down:      "DOWN",
      badge_standby:   "STANDBY",
      badge_active:    "ACTIVE",
      badge_online:    "ONLINE",
      badge_offline:   "OFFLINE",
      badge_ok:        "OK",
      badge_warn:      "WARNUNG",
      badge_unknown:   "UNBEKANNT",

      // Inline-Status-Worte (Kleinschreibung, werden mitgelokalisiert)
      state_active:    "aktiv",
      state_running:   "läuft",
      leg_active:      "aktiv",
      leg_down:        "ausgefallen",
      leg_standby:     "Bereitschaft",
      state_set:       "gesetzt",
      state_fail_only: "nur Fehler-Telegram",
      never:           "nie",
      demo_data:       "Demo-Daten · kein Live-Collector",


      svg_title: "Pi-hole DNS-Failover Architektur",
      svg_desc:  "Clients schicken DNS-Anfragen an die VIP; dahinter läuft dnsdist (per keepalived/VRRP normal auf der dns-ha-VM, beim Ausfall auf dem Pi Zero — identische Konfiguration auf beiden Knoten). dnsdist nutzt die firstAvailable-Policy: Anfragen gehen an den Primary Pi-hole auf dem Server (Reihenfolge 1), solange dessen Health-Check besteht, sonst an die lokale Pi Zero FTL-Instanz (Reihenfolge 2). Health-Check alle 5 Sekunden; der Primary gilt nach 4 aufeinanderfolgenden Fehlversuchen als down, der Fallback nach 2.",
    },
    en: {
      skip_to_main:    "Skip to main content",

      app_title:       "Pi-hole Failover",
      app_sub:         "dnsdist · failover · live",

      sb_pizero:       "Pi Zero · dnsdist",
      sb_primary:      "Primary · Server",
      sb_fallback:     "Fallback · Pi Zero FTL",
      sb_bot:      "Telegram Bot",
      sb_update:       "Update",

      section_cards:    "Components",
      section_recovery: "Recovery · emergency reboot",
      section_events:   "Events",

      card_clients_num:   "Card 1",
      card_pizero_num:    "Card 2",
      card_primary_num:   "Card 3",
      card_fallback_num:  "Card 4",
      card_bot_num:   "Card 5",
      card_update_num:    "Card 6",

      card_clients_title:  "Clients & DHCP",
      card_pizero_title:   "Pi Zero · dnsdist",
      card_primary_title:  "Primary · Server",
      card_fallback_title: "Fallback · Pi Zero FTL",
      card_bot_title:  "Reboot safety · Telegram bot",
      card_update_title:   "Weekly update cron",

      card_clients_dns_ip:      "DNS IP",
      card_clients_dhcp_range:  "DHCP range",
      card_clients_router:      "Router",
      card_clients_reservation: "Reservation",

      card_pizero_host:    "Host",
      card_pizero_vip:     "VRRP role",
      val_pizero_vrrp:     "BACKUP · prio 100",
      card_pizero_uptime:  "Uptime",
      card_pizero_policy:  "Policy",
      card_pizero_systemd: "systemd",
      hint_pizero_vip:     "takes VIP <VIP> only if the dns-ha VM fails · admin UI always at the Pi Zero IP",

      card_primary_host:      "Host",
      card_primary_weight:    "Order",
      card_primary_health:    "Health",
      card_primary_container: "Container",
      card_primary_rt:        "Last RT",
      card_primary_webui:     "Web UI",
      hint_primary_webui:     "shows real client queries",

      card_fallback_host:     "Host",
      card_fallback_weight:   "Order",
      card_fallback_health:   "Health",
      card_fallback_ftl:      "Pi-hole FTL",
      card_fallback_takeover: "Last takeover",
      card_fallback_webui:    "Web UI",
      hint_fallback_webui:    "normal mode: health-checks only",

      card_bot_handle:   "Bot",
      card_bot_service:  "Service",
      card_bot_contact:  "Last contact",
      card_bot_cooldown: "Cooldown",
      card_bot_pin:      "PIN",
      card_bot_audit:    "Audit count",

      card_update_last:   "Last run",
      card_update_method: "Method",
      card_update_alert:  "Alert",
      card_update_next:   "Next run",

      flow_f1_sub:   "Client queries",
      flow_health:   "health-check · 5 s · primary 4 fails = down",
      flow_caption:  "FritzBox DHCP pushes the VIP as DNS → dnsdist behind the VIP (via keepalived, normally on the dns-ha VM) routes to the primary while healthy, else the fallback",
      node_clients:  "Clients · FritzBox",
      node_primary:  "Primary · Server",
      node_fallback: "Fallback · Pi Zero FTL",

      hero_normal:        "All systems normal — primary serving, fallback on standby",
      hero_primary_down:  "⚠ PRIMARY DOWN — fallback taking over",
      hero_fallback_down: "Primary serving — fallback standby unhealthy",
      hero_both_down:     "❌ BOTH BACKENDS DOWN — DNS offline",
      hero_stale:         "⚠ Collector stale — no fresh data",
      hero_unknown:       "Status unknown",
      since:              "since",

      state_online_ready:   "online · ready",
      state_offline:        "offline",
      recovery_last_contact:"last contact · {age}",
      recovery_emergency:   "emergency reboot",
      recovery_reboot:      " reboot",
      recovery_via:         "via sudo shutdown -r now",

      events_empty:         "No events yet — system running fresh.",

      alert_title:          "⚠ PRIMARY DOWN",
      alert_sub_template:   "Fallback serving · since {age}",

      badge_listening: "LISTENING",
      badge_up:        "UP",
      badge_down:      "DOWN",
      badge_standby:   "STANDBY",
      badge_active:    "ACTIVE",
      badge_online:    "ONLINE",
      badge_offline:   "OFFLINE",
      badge_ok:        "OK",
      badge_warn:      "WARN",
      badge_unknown:   "UNKNOWN",

      state_active:    "active",
      state_running:   "running",
      leg_active:      "active",
      leg_down:        "down",
      leg_standby:     "standby",
      state_set:       "set",
      state_fail_only: "fail-only telegram",
      never:           "never",
      demo_data:       "Demo data · no live collector",


      svg_title: "Pi-hole DNS failover architecture",
      svg_desc:  "Clients send DNS queries to the VIP; behind it runs dnsdist (via keepalived/VRRP normally on the dns-ha VM, on the Pi Zero if that fails — identical config on both nodes). dnsdist uses the firstAvailable policy: it sends queries to the primary Pi-hole on the server (order 1) as long as its health-check passes, and falls back to the local Pi Zero FTL instance (order 2) otherwise. Health-check every 5 seconds; the primary is marked down after 4 consecutive failures, the fallback after 2.",
    },
  };

  const STORAGE_KEY = "pihole-ha.lang";
  const SUPPORTED   = ["de", "en"];
  const DEFAULT     = "de";

  function pickInitialLang() {
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      if (saved && SUPPORTED.includes(saved)) return saved;
    } catch (_) { /* no-op */ }

    const nav = (navigator.language || "").toLowerCase();
    if (nav.startsWith("en")) return "en";
    return DEFAULT;
  }

  function applyLang(lang) {
    const dict = I18N[lang] || I18N[DEFAULT];

    document.documentElement.setAttribute("lang", lang);

    // Text content swap
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const key = el.getAttribute("data-i18n");
      const val = dict[key];
      if (val !== undefined) el.textContent = val;
    });

    // Attribute swap: data-i18n-attr="title:key,aria-label:key"
    document.querySelectorAll("[data-i18n-attr]").forEach((el) => {
      const spec = el.getAttribute("data-i18n-attr") || "";
      spec.split(",").forEach((pair) => {
        const [attr, key] = pair.split(":").map((s) => s && s.trim());
        if (!attr || !key) return;
        const val = dict[key];
        if (val !== undefined) el.setAttribute(attr, val);
      });
    });

    // Lang-Button aktive Markierung
    document.querySelectorAll(".lang-btn").forEach((btn) => {
      const active = btn.getAttribute("data-lang") === lang;
      btn.classList.toggle("is-active", active);
      btn.setAttribute("aria-pressed", active ? "true" : "false");
    });

    try { localStorage.setItem(STORAGE_KEY, lang); } catch (_) { /* no-op */ }

    // Live-state elements carry a data-i18n default that the swap above just
    // reset to the dictionary default. Repaint them from the cached payload so
    // a language switch mid-failover keeps the real state. No-op before tick().
    rerenderFromCache();
  }

  // Expose for future modules (and manual dev-toggle via console)
  window.PiholeHA = Object.assign(window.PiholeHA || {}, {
    t: (key, lang) => {
      const l = lang || document.documentElement.getAttribute("lang") || DEFAULT;
      return (I18N[l] && I18N[l][key]) || I18N[DEFAULT][key] || key;
    },
    setLang: applyLang,
    currentLang: () => document.documentElement.getAttribute("lang") || DEFAULT,
  });

  // ── Lang-Switcher wiring ──────────────────────────────────────
  document.querySelectorAll(".lang-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      const lang = btn.getAttribute("data-lang");
      if (lang) applyLang(lang);
    });
  });

  // ── Initial apply ─────────────────────────────────────────────
  applyLang(pickInitialLang());

  /* ──────────────────────────────────────────────────────────────
     Data Fetching + Rendering
     ────────────────────────────────────────────────────────────── */

  const DATA_URL      = "data.json";
  const DATA_FALLBACK = "data.sample.json";
  const HIST_URL      = "history.json";
  const HIST_FALLBACK = "history.sample.json";
  const REFRESH_MS    = 15_000;
  const STALE_MS      = 120_000;

  async function fetchJson(primary, fallback) {
    try {
      const r = await fetch(`${primary}?_=${Date.now()}`, { cache: "no-store" });
      if (r.ok) return { data: await r.json(), isDemo: false };
    } catch (_) { /* no-op, try fallback */ }
    try {
      const r = await fetch(fallback, { cache: "no-store" });
      if (r.ok) return { data: await r.json(), isDemo: true };
    } catch (_) { /* no-op */ }
    return { data: null, isDemo: false };
  }

  function fmtRelative(iso, lang) {
    if (!iso) return null;
    const then = new Date(iso).getTime();
    if (Number.isNaN(then)) return null;
    const diffS = Math.max(0, Math.round((Date.now() - then) / 1000));
    const rtf = new Intl.RelativeTimeFormat(lang, { numeric: "auto" });
    if (diffS < 60)    return rtf.format(-diffS, "second");
    if (diffS < 3600)  return rtf.format(-Math.round(diffS / 60), "minute");
    if (diffS < 86400) return rtf.format(-Math.round(diffS / 3600), "hour");
    return rtf.format(-Math.round(diffS / 86400), "day");
  }

  function fmtDuration(s) {
    if (s == null || Number.isNaN(s)) return "–";
    s = Math.max(0, Math.floor(s));
    if (s < 60)   return `${s} s`;
    if (s < 3600) return `${Math.floor(s / 60)} m`;
    if (s < 86400) {
      const h = Math.floor(s / 3600);
      const m = Math.floor((s % 3600) / 60);
      return m ? `${h}h ${m}m` : `${h}h`;
    }
    const d = Math.floor(s / 86400);
    const h = Math.floor((s % 86400) / 3600);
    return h ? `${d}d ${h}h` : `${d}d`;
  }

  function setText(sel, value) {
    const el = document.querySelector(sel);
    if (el && value != null) el.textContent = value;
  }

  function t(key) {
    return window.PiholeHA.t(key);
  }

  function renderStatusbar(data) {
    const lang = window.PiholeHA.currentLang();
    if (!data) {
      setText("#sb-pizero-state",   "–");
      setText("#sb-primary-state",  "–");
      setText("#sb-fallback-state", "–");
      setText("#sb-bot-state",  "–");
      setText("#sb-update-state",   "–");
      return;
    }

    const dn = data.dnsdist || {};
    setText(
      "#sb-pizero-state",
      dn.state === "listening" ? t("leg_active")
      : dn.state === "unknown" ? "–"
      :                          t("leg_down"),
    );

    const prim = (dn.primary || {}).state;
    setText(
      "#sb-primary-state",
      prim === "up"      ? t("leg_active")
      : prim === "unknown" ? "–"
      :                     t("leg_down"),
    );

    const fb = (dn.fallback || {}).state;
    const role = (data.monitor || {}).role || "normal";
    const fbLabel =
      fb === "unknown"             ? "–"
      : role === "normal"          ? t("leg_standby")
      : role === "primary_down"    ? t("leg_active")
      : fb === "up"                ? t("leg_standby")
      :                             t("leg_down");
    setText("#sb-fallback-state", fbLabel);

    const ot = data.bot || {};
    setText("#sb-bot-state", ot.state === "online" ? "ok" : t("state_offline"));

    const upd = data.update || {};
    const rel = fmtRelative(upd.last_run_ts, lang);
    setText("#sb-update-state", rel || "–");
  }

  function renderCards(data) {
    if (!data) return;
    const dn = data.dnsdist || {};
    const lang = window.PiholeHA.currentLang();

    // Card 2: Pi Zero
    setText("#v-pizero-uptime", fmtDuration(dn.uptime_s));
    setText(
      "#card-pizero-badge",
      dn.state === "listening" ? t("badge_listening")
      : dn.state === "unknown" ? t("badge_unknown")
      :                          t("badge_down"),
    );

    // Card 3: Primary
    const p = dn.primary || {};
    const rt = p.rt_ms != null ? `${p.rt_ms} ms` : "–";
    setText("#v-primary-rt", rt);
    const primaryBadge = document.getElementById("card-primary-badge");
    if (primaryBadge) {
      primaryBadge.textContent =
        p.state === "up"      ? `${t("badge_up")} · ${rt}`
        : p.state === "unknown" ? t("badge_unknown")
        :                       t("badge_down");
    }

    // Card 4: Fallback
    const f = dn.fallback || {};
    const role = (data.monitor || {}).role || "normal";
    const fbBadge = document.getElementById("card-fallback-badge");
    if (fbBadge) {
      fbBadge.textContent =
        f.state === "unknown"   ? t("badge_unknown")
        : role === "primary_down" ? t("badge_active")
        : f.state === "up"       ? t("badge_standby")
        :                          t("badge_down");
    }
    setText(
      "#v-fallback-takeover",
      (data.monitor || {}).last_takeover_ts
        ? fmtRelative((data.monitor || {}).last_takeover_ts, lang)
        : t("never"),
    );

    // Card 5: Telegram bot
    const ot = data.bot || {};
    setText(
      "#card-bot-badge",
      ot.state === "online" ? t("badge_online") : t("badge_offline"),
    );
    setText("#v-bot-contact", ot.last_contact_s != null ? fmtDuration(ot.last_contact_s) : "–");
    setText("#v-bot-audit", ot.audit_count_30d != null ? `${ot.audit_count_30d} · 30d` : "–");

    // Card 6: Update
    const upd = data.update || {};
    const updBadge = document.getElementById("card-update-badge");
    if (updBadge) {
      updBadge.textContent =
        upd.last_result === "ok"        ? t("badge_ok")
        : !upd.last_result || upd.last_result === "unknown" ? t("badge_unknown")
        :                                 t("badge_down");
    }
    const updRel = fmtRelative(upd.last_run_ts, lang);
    setText("#v-update-last", updRel || "–");

    // Flow node badges
    const fnPrimaryBadge  = document.getElementById("fn-primary-badge");
    const fnFallbackBadge = document.getElementById("fn-fallback-badge");
    if (fnPrimaryBadge) {
      fnPrimaryBadge.textContent =
        p.state === "up"      ? `${t("badge_up")} · ${rt}`
        : p.state === "unknown" ? t("badge_unknown")
        :                       t("badge_down");
    }
    if (fnFallbackBadge) {
      fnFallbackBadge.textContent =
        f.state === "unknown"   ? t("badge_unknown")
        : role === "primary_down" ? t("badge_active")
        : f.state === "up"       ? t("badge_standby")
        :                          t("badge_down");
    }
  }

  function isStale(data) {
    if (!data || !data.ts) return true;
    const then = new Date(data.ts).getTime();
    if (Number.isNaN(then)) return true;
    return (Date.now() - then) > STALE_MS;
  }

  const EVENT_META = {
    failover:    { icon: "▼", label: "FAILOVER" },
    recovery:    { icon: "▲", label: "RECOVERY" },
    update:      { icon: "⚙", label: "UPDATE" },
    telegram:    { icon: "✉", label: "TELEGRAM" },
    healthcheck: { icon: "⚕", label: "HEALTHCHECK" },
    reboot:      { icon: "⏻", label: "REBOOT" },
    warning:     { icon: "⚠", label: "WARNING" },
    critical:    { icon: "⛔", label: "CRITICAL" },
  };

  function fmtEventTime(iso) {
    if (!iso) return "";
    const d = new Date(iso);
    if (Number.isNaN(d.getTime())) return "";
    const now = new Date();
    const sameDay =
      d.getFullYear() === now.getFullYear() &&
      d.getMonth() === now.getMonth() &&
      d.getDate() === now.getDate();
    if (sameDay) {
      return d.toLocaleTimeString(undefined, { hour12: false, hour: "2-digit", minute: "2-digit", second: "2-digit" });
    }
    const diffH = (now - d) / 3600000;
    if (diffH < 24 * 7) {
      return d.toLocaleDateString(undefined, { weekday: "short" }) + " " +
             d.toLocaleTimeString(undefined, { hour12: false, hour: "2-digit", minute: "2-digit" });
    }
    return d.toLocaleDateString(undefined, { month: "2-digit", day: "2-digit" }) + " " +
           d.toLocaleTimeString(undefined, { hour12: false, hour: "2-digit", minute: "2-digit" });
  }

  function renderEvents(history) {
    const list  = document.getElementById("events-list");
    const empty = document.getElementById("events-empty");
    if (!list || !empty) return;

    const items = Array.isArray(history)
      ? [...history].sort((a, b) => new Date(b.ts) - new Date(a.ts)).slice(0, 15)
      : [];
    if (items.length === 0) {
      list.hidden = true;
      empty.hidden = false;
      list.replaceChildren();
      return;
    }

    empty.hidden = true;
    list.hidden = false;
    const frag = document.createDocumentFragment();
    items.forEach((ev) => {
      const type = (ev.type || "").toLowerCase();
      const meta = EVENT_META[type] || { icon: "·", label: (ev.type || "EVENT").toUpperCase() };
      const li = document.createElement("li");
      li.className = `event-row event-row--${type}`;

      const time = document.createElement("span");
      time.className = "event-row__time";
      time.textContent = fmtEventTime(ev.ts);

      const typeEl = document.createElement("span");
      typeEl.className = "event-row__type";
      typeEl.textContent = `${meta.icon}  ${meta.label}`;

      const msg = document.createElement("span");
      msg.className = "event-row__msg";
      msg.textContent = ev.msg || "";

      const delta = document.createElement("span");
      delta.className = "event-row__delta";
      delta.textContent = ev.delta_s != null ? `Δ ${fmtDuration(ev.delta_s)}` : "";

      const src = document.createElement("span");
      src.className = "event-row__src";
      src.textContent = ev.src || "";

      li.append(time, typeEl, msg, delta, src);
      frag.append(li);
    });
    list.replaceChildren(frag);
  }

  let _lastAuditCount = null;
  let _triggerResetTimeout = null;
  function renderRecoveryStrip(data, stale) {
    const strip       = document.getElementById("recovery-strip");
    const botDot  = document.querySelector("#recovery-bot .recovery-node__dot");
    const stateSpan   = document.querySelector("#recovery-bot .recovery-node__state");
    const lastContact = document.getElementById("recovery-last-contact");
    if (!strip) return;

    const ot = (data && data.bot) || {};
    const online = !stale && ot.state === "online";

    if (stateSpan) {
      stateSpan.textContent = online ? t("state_online_ready") : t("state_offline");
    }
    if (botDot) {
      botDot.style.background   = online ? "var(--c-fallback)" : "var(--c-warn)";
      botDot.style.boxShadow    = online ? "0 0 10px var(--c-fallback)" : "0 0 10px var(--c-warn)";
    }
    if (lastContact) {
      const since = ot.last_contact_s != null ? fmtDuration(ot.last_contact_s) : "–";
      const template = t("recovery_last_contact");
      lastContact.textContent = template.replace("{age}", since);
    }

    // Trigger-Flash on new audit entry (audit_count_30d increased)
    const ac = ot.audit_count_30d != null ? ot.audit_count_30d : null;
    if (ac != null && _lastAuditCount != null && ac > _lastAuditCount) {
      strip.classList.add("is-triggered");
      clearTimeout(_triggerResetTimeout);
      _triggerResetTimeout = setTimeout(() => strip.classList.remove("is-triggered"), 1900);
    }
    if (ac != null) _lastAuditCount = ac;
  }

  function renderHeroStatus(data, stale) {
    const hero = document.getElementById("hero-status");
    const txt  = document.getElementById("hero-status-text");
    if (!hero || !txt) return;

    hero.classList.remove(
      "hero-status--normal", "hero-status--warn",
      "hero-status--failover", "hero-status--catastrophe",
      "hero-status--stale",
    );

    if (stale || !data) {
      hero.classList.add("hero-status--stale");
      txt.textContent = t("hero_stale");
      return;
    }

    const role = deriveRole(data);
    const lang = window.PiholeHA.currentLang();
    let sinceSuffix = "";
    const takeover = (data.monitor || {}).last_takeover_ts;
    if ((role === "primary_down" || role === "both_down") && takeover) {
      const rel = fmtRelative(takeover, lang);
      if (rel) sinceSuffix = ` — ${t("since")} ${rel}`;
    }

    if (role === "normal") {
      hero.classList.add("hero-status--normal");
      txt.textContent = t("hero_normal");
    } else if (role === "primary_down") {
      hero.classList.add("hero-status--failover");
      txt.textContent = t("hero_primary_down") + sinceSuffix;
    } else if (role === "fallback_down") {
      hero.classList.add("hero-status--warn");
      txt.textContent = t("hero_fallback_down");
    } else if (role === "both_down") {
      hero.classList.add("hero-status--catastrophe");
      txt.textContent = t("hero_both_down") + sinceSuffix;
    } else {
      hero.classList.add("hero-status--stale");
      txt.textContent = t("hero_unknown");
    }
  }

  function deriveRole(data) {
    if (!data || !data.dnsdist) return "unknown";
    const prim = ((data.dnsdist.primary || {}).state || "").toLowerCase();
    const fb   = ((data.dnsdist.fallback || {}).state || "").toLowerCase();
    // Collection failed: dnsdist state is genuinely unknown, not "down".
    if (data.dnsdist.state === "unknown" || prim === "unknown" || fb === "unknown") return "unknown";
    if (prim === "up" && fb === "up")     return "normal";
    if (prim !== "up" && fb === "up")     return "primary_down";
    if (prim === "up" && fb !== "up")     return "fallback_down";
    if (prim !== "up" && fb !== "up")     return "both_down";
    return "unknown";
  }

  function applyStateClasses(data, stale) {
    const role = deriveRole(data) || "unknown";
    document.documentElement.setAttribute("data-role", role);

    const cardPrimary  = document.getElementById("card-primary");
    const cardFallback = document.getElementById("card-fallback");
    const fnPrimary    = document.getElementById("fn-primary");
    const fnFallback   = document.getElementById("fn-fallback");
    const sbDotPrimary  = document.querySelector("#sb-primary  .sb-dot");
    const sbDotFallback = document.querySelector("#sb-fallback .sb-dot");
    const sbDotPizero   = document.querySelector("#sb-pizero   .sb-dot");
    const sbDotBot  = document.querySelector("#sb-bot  .sb-dot");
    const sbDotUpdate   = document.querySelector("#sb-update   .sb-dot");
    const pulseDot      = document.getElementById("pulse-dot");
    const statusbar     = document.getElementById("statusbar");

    [cardPrimary, cardFallback, fnPrimary, fnFallback].forEach((el) => {
      if (!el) return;
      el.classList.remove("is-down", "is-active", "is-warn");
    });
    [sbDotPrimary, sbDotFallback, sbDotPizero, sbDotBot, sbDotUpdate].forEach((el) => {
      if (!el) return;
      el.classList.remove("is-down", "is-active", "is-warn");
    });
    if (pulseDot) pulseDot.classList.remove("is-warn", "is-down");
    if (statusbar) statusbar.classList.remove("is-alert");

    if (!data || stale) {
      if (pulseDot) pulseDot.classList.add("is-warn");
      return;
    }

    if (role === "primary_down" || role === "both_down") {
      cardPrimary  && cardPrimary.classList.add("is-down");
      fnPrimary    && fnPrimary.classList.add("is-down");
      sbDotPrimary && sbDotPrimary.classList.add("is-down");
    }
    if (role === "primary_down") {
      cardFallback  && cardFallback.classList.add("is-active");
      fnFallback    && fnFallback.classList.add("is-active");
      sbDotFallback && sbDotFallback.classList.add("is-active");
    }
    if (role === "fallback_down") {
      cardFallback  && cardFallback.classList.add("is-warn");
      fnFallback    && fnFallback.classList.add("is-warn");
      sbDotFallback && sbDotFallback.classList.add("is-warn");
    }
    if (role === "both_down") {
      cardFallback  && cardFallback.classList.add("is-down");
      fnFallback    && fnFallback.classList.add("is-down");
      sbDotFallback && sbDotFallback.classList.add("is-down");
    }

    const dn = data.dnsdist || {};
    if (dn.state && dn.state !== "listening" && dn.state !== "unknown") {
      sbDotPizero && sbDotPizero.classList.add("is-down");
    }

    const ot = data.bot || {};
    if (ot.state !== "online") {
      sbDotBot && sbDotBot.classList.add("is-warn");
    }

    const upd = data.update || {};
    if (upd.last_result && upd.last_result !== "ok" && upd.last_result !== "unknown") {
      sbDotUpdate && sbDotUpdate.classList.add("is-warn");
    }

    if (role === "primary_down" || role === "fallback_down") {
      if (pulseDot) pulseDot.classList.add("is-warn");
      if (statusbar && role === "primary_down") statusbar.classList.add("is-alert");
    }
    if (role === "both_down") {
      if (pulseDot) pulseDot.classList.add("is-down");
      if (statusbar) statusbar.classList.add("is-alert");
    }
  }

  function rerenderFromCache() {
    const P = window.PiholeHA || {};
    if (!P._lastData) return;
    renderStatusbar(P._lastData);
    renderCards(P._lastData);
    applyStateClasses(P._lastData, P._lastStale);
    renderHeroStatus(P._lastData, P._lastStale);
    renderRecoveryStrip(P._lastData, P._lastStale);
    renderEvents(P._lastHistory);
  }

  async function tick() {
    const [dataRes, histRes] = await Promise.all([
      fetchJson(DATA_URL, DATA_FALLBACK),
      fetchJson(HIST_URL, HIST_FALLBACK),
    ]);
    const data    = dataRes.data;
    const history = histRes.data;

    // Demo mode (data.json unreachable, e.g. a static GitHub Pages deploy
    // with no live collector): the sample timestamp is fixed, so the normal
    // staleness check would always trip and make the demo look broken.
    const stale = dataRes.isDemo ? false : isStale(data);
    document.documentElement.classList.toggle("is-stale", stale);

    // Demo mode has no live collector — say so, so a green board is not
    // mistaken for a healthy live system.
    const demoBadge = document.getElementById("demo-badge");
    if (demoBadge) demoBadge.hidden = !dataRes.isDemo;

    const pulse = document.getElementById("pulse-dot");
    if (pulse) {
      pulse.classList.remove("is-warn", "is-down");
      if (stale) pulse.classList.add("is-warn");
    }

    renderStatusbar(data);
    renderCards(data);
    applyStateClasses(data, stale);
    renderHeroStatus(data, stale);
    renderRecoveryStrip(data, stale);
    renderEvents(history);

    window.PiholeHA._lastData = data;
    window.PiholeHA._lastHistory = history;
    window.PiholeHA._lastStale = stale;
  }

  tick();
  setInterval(tick, REFRESH_MS);
})();
