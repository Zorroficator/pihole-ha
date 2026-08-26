<img src="docs/banner-combined.svg" alt="pihole-ha banner" width="100%">

# pihole-ha

Ein einzelner Pi-hole ist im Heimnetz ein klassischer Single Point of Failure für DNS: fällt er aus, geht bei vielen Clients gar nichts mehr, weil DNS-Auflösung meist am Anfang jeder Verbindung steht. Dieses Repo dokumentiert ein Setup mit **zwei Pi-hole-Instanzen und automatischem Failover** — kombiniert aus `dnsdist` (DNS-Lastverteilung/Health-Check zwischen den beiden Pi-hole-Backends) und `keepalived` (hält eine virtuelle IP per VRRP zwischen den beiden Hosts hoch verfügbar). Fällt eine Instanz aus, übernimmt die andere automatisch, ohne dass Clients etwas davon merken.

> **Hinweis:** Dies ist ein privates Hobby-/Heimnetzprojekt und als Machbarkeitsstudie zu verstehen, kein produktionsreifes oder offiziell gepflegtes Paket. Es wird ohne jegliche Garantie bereitgestellt — Nutzung auf eigene Gefahr. Vor dem Einsatz im eigenen Netz sollte das Setup geprüft und an die eigene Umgebung angepasst werden.

## Status

**Live seit 18.04.2026.** Autonomer Power-Cycle-Recovery getestet (Recovery-Zeit <1:15 min, DNS-Kontinuität ohne Client-Ausfall).

## Voraussetzungen

- Ein Raspberry Pi Zero 2W mit [DietPi](https://dietpi.com/)
- Ein zweiter Host mit Docker (im Original ein Mac mit [OrbStack](https://orbstack.dev/), funktioniert aber mit jedem Docker-fähigen Host)
- Dein Router (z. B. eine FritzBox/AVM-Gerät) mit konfigurierbarem DNS-Server
- Grundkenntnisse in systemd (Linux-Seite) bzw. launchd (macOS-Seite), da beide Hosts eigene Units/Agents für Monitoring und Wartung mitbringen

## Architektur

Zwei HA-Mechanismen greifen ineinander:

- **`keepalived`** hält eine virtuelle IP (`<VIP>`) per VRRP zwischen dem Pi Zero und dem Docker-Host hoch verfügbar. Fällt einer der beiden Knoten aus, übernimmt der andere automatisch die VIP — die Clients merken vom Knotenwechsel selbst nichts.
- **`dnsdist`** läuft auf beiden Knoten und macht dahinter das eigentliche DNS-Failover zwischen dem primären und dem Fallback-Pi-hole: Queries gehen an das primäre Pi-hole, solange dessen Health-Check grün ist; bei Ausfall schaltet dnsdist automatisch auf das Fallback-Pi-hole um.

```
Clients → Router verteilt DNS <VIP>
          │
          ▼
Pi Zero (<PIZERO_IP> + <VIP>/32 Alias)
  └─ dnsdist :53
       ├─ primary  → <SERVER_IP>:5301 (Pi-hole im Docker-Container, weight 10)
       └─ fallback → 127.0.0.1:5353 (Pi-hole-FTL lokal auf Pi Zero, weight 1)

Health-Check alle 5 s · 2 Fails → down · Policy firstAvailable
```

Hinweis zu den Ports: `dnsdist` braucht Port 53 im selben Host-Netz für sich selbst
(als der eigentliche VIP-Endpunkt). Das Pi-hole im Docker-Container läuft deshalb dahinter
auf Port 5301, nicht auf 53 — sonst würden sich beide Dienste den Port streitig machen.

```mermaid
flowchart TB
    Client([Client-Geräte]) --> VIP{{"Virtuelle IP<br/>(keepalived / VRRP)"}}
    VIP -->|hält Knoten hoch verfügbar| DNSDist[dnsdist<br/>Health-Check + Failover]
    DNSDist -->|primary, solange gesund| Primary[(Pi-hole primary<br/>Docker-Host)]
    DNSDist -.->|fallback bei Ausfall| Fallback[(Pi-hole fallback<br/>Pi Zero)]

    Primary -->|Ausfall erkannt| Alert[Telegram-Alert]
    Alert -.optional.-> Bot[Telegram-Bot:<br/>Notfall-Reboot]
    Alert -.letzte Option.-> Router[Router-DNS manuell<br/>auf Fallback-IP umstellen]

    classDef ok fill:#0f172a,stroke:#22d3ee,color:#e2e8f0;
    classDef warn fill:#0f172a,stroke:#fb923c,color:#e2e8f0;
    class VIP,DNSDist,Primary ok;
    class Fallback,Alert,Bot,Router warn;
```

Warum der Pi Zero die VIP mit übernehmen kann und nicht dauerhaft nur der Docker-Host: bei manchen Docker-Netzwerk-Setups (hier: ein bekannter OrbStack-NAT-Bug) kommen Container-Antworten immer von der Host-Primary-IP statt vom VIP-Alias — deshalb hält der Pi Zero im Normalbetrieb die VIP, und `dnsdist` übernimmt das eigentliche Backend-Failover dahinter.

## Komponenten

- **Pi Zero** (`<PIZERO_IP>` + VIP `<VIP>`): dnsdist, Pi-hole-FTL (loopback :5353), Monitor, Health-Logger, Wartungs-Cron (`pihole -up` + Gravity), systemd-Units
- **Docker-Host** (`<SERVER_IP>`): Pi-hole-Container, DNS-Heartbeat-LaunchAgent
- **Telegram-Bot** (optionale Erweiterung, nicht Teil dieses Repos): ein externer Bot für den Notfall-Reboot des Docker-Hosts, gehärtet via Sudoers/SSH-Key. Ersetzbar durch jeden anderen Fernzugriffsweg (SSH, Steckdosen-Reboot, etc.) — siehe Sicherheitshinweis unten.

## Recovery-Kette

1. **Automatisch:** Primary fällt aus → dnsdist erkennt es in <15 s → Fallback liefert weiter → Telegram-Alert
2. **Manuell (bei hängendem Docker-Host):** Reboot per Telegram-Bot oder SSH auslösen
3. **Letzte Option (bei Totalausfall des Pi Zero):** Router-DNS manuell auf `<ROUTER_IP>` umstellen (SPOF bewusst akzeptiert)

## Monitoring & Crash-Forensik

- **Health-Logger** (Pi Zero, `pi_zero/pi_health_logger.sh`): Cron `@reboot` + alle 20 min. Schreibt kompakte Health-Datensätze nach `~/data/pi_health/health.jsonl` — persistent auf der SD, überlebt den DietPi-RAMlog-Wipe (`/var/log` liegt im RAM). Erfasst Uptime, Load, freien RAM, Temperatur, Undervoltage-Meldungen und ob der vorige Boot sauber war; dmesg-Snapshots bei Auffälligkeiten. Liefert nach einem Ausfall die Spur, die der RAM-only-Logmodus sonst verschluckt.
- **DNS-Heartbeat** (Docker-Host, `server/pihole_heartbeat.sh` + LaunchAgent): prüft alle 5 min funktional per `dig` über die VIP `<VIP>`. Telegram-Alarm nur bei Ausfall (nach 15 min), Recovery-Meldung, wöchentlicher Sonntag-Heartbeat. Schließt die Lücke, dass der Monitor *auf* dem Pi sich nicht selbst totmelden kann.

## Dashboard

Ein statisches Status-Dashboard liegt unter `dashboard/` (`index.html`, `app.js`, `style.css`). Es zeigt Primary/Fallback-Status, Health-Checks, Update-Cron und den optionalen Telegram-Bot als Live-Ansicht mit DE/EN-Umschalter.

- **Datenquelle:** `dashboard/app.js` lädt `data.json` + `history.json` per Fetch; sind diese nicht erreichbar (z. B. weil kein Collector läuft), fällt es automatisch auf `data.sample.json` / `history.sample.json` zurück. Damit läuft das Dashboard auch **ohne Backend** — z. B. als reine Demo per GitHub Pages, direkt aus diesem Repo.
- **Live-Betrieb:** `server/dashboard_collector.py` sammelt Status per SSH vom Pi Zero (dnsdist-API, Monitor-State, Telegram-Bot-State) plus lokal das Update-Log und schreibt `data.json` + `history.json`. Als Cron/LaunchAgent auf dem Docker-Host laufen lassen und die Dateien neben `index.html` bereitstellen (z. B. via Webserver-Rootverzeichnis).

## Platzhalter ersetzen

Die Konfigurationsdateien in diesem Repo enthalten Platzhalter statt echter Netzwerkadressen. Vor dem Deploy müssen sie durch die eigenen Werte ersetzt werden — betroffen sind u. a. `keepalived/*.conf`, `pi_zero/monitor_config.toml`, `pi_zero/dnsdist.conf`, `docker-compose.yml`, `server/*.sh` und `pi_zero/*.sh`:

| Platzhalter | Bedeutung |
|---|---|
| `<VIP>` | Virtuelle IP, die per VRRP zwischen den beiden Hosts floatet |
| `<SERVER_IP>` | IP des Docker-Hosts |
| `<PIZERO_IP>` | IP des Raspberry Pi Zero 2W |
| `<PIZERO_TAILSCALE_IP>` | Tailscale-IP des Raspberry Pi Zero 2W (für SSH-Zugriff vom Docker-Host aus) |
| `<PI_USER>` | SSH-Login-User auf dem Raspberry Pi Zero 2W (z. B. der DietPi-Standarduser) |
| `<DNS_HA_VM_IP>` | IP des keepalived-Knotens auf dem Docker-Host (falls dieser in einer VM läuft) |
| `<ROUTER_IP>` | IP des Routers als DNS-Fallback der letzten Option |
| `<LAN_SUBNET>` | Heimnetz-Subnetz für ACLs/Firewall-Regeln |
| `<PIN>` | PIN für den Notfall-Reboot-Befehl des Telegram-Bots (`pi_zero/pihole_monitor.py`) |
| `<STATE>` | VRRP-Statusparameter, den keepalived beim Aufruf von `keepalived/notify_telegram.sh` übergibt (nicht manuell zu ersetzen) |

Am einfachsten alle Vorkommen im Repo suchen (`grep -rn '<[A-Z_]*>' .`) und gezielt ersetzen.

## Deploy

```bash
# Pi-hole auf dem Docker-Host
cd pihole-ha && docker compose up -d

# Pi Zero
cd pi_zero && ./deploy.sh

# Monitoring (Health-Logger + DNS-Heartbeat) auf beide Hosts
./deploy_monitoring.sh

# Dashboard (statische Dateien + optionaler Collector) auf dem Docker-Host
# dashboard/*.html, *.js, *.css, *.sample.json auf einen Webserver legen;
# für Live-Daten zusätzlich server/dashboard_collector.py per Cron/LaunchAgent
# alle 60 s laufen lassen (schreibt data.json + history.json neben index.html)
```

## Runbooks

Setup: `pi_zero/deploy.sh`. Status-/Health-Checks der dnsdist-Backends: `pi_zero/pihole_monitor.py`. DNS-Heartbeat auf dem Docker-Host: `server/pihole_heartbeat.sh`. Dashboard-Datensammlung: `server/dashboard_collector.py`.

## Sicherheitshinweis

Der optionale Telegram-Bot für den Notfall-Reboot hat bewusst eingeschränkte Rechte: Zugriff nur über einen dedizierten SSH-Key und eine eng gefasste Sudoers-Regel (nur der Reboot-Befehl, keine Shell). Wer diesen Weg nicht nutzen möchte, kann Schritt 2 der Recovery-Kette genauso gut per manuellem SSH-Zugriff abbilden.

## Demo

Statische Demo des Dashboards mit den mitgelieferten Sample-Daten (ohne Backend): **[zorroficator.github.io/pihole-ha](https://zorroficator.github.io/pihole-ha/)**

## Offene Arbeiten

- Integration als eigenes Panel in einem übergeordneten Heimnetz-Dashboard

## License

[MIT](LICENSE)
