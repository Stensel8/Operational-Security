# Week 1-2: SIEM

Wazuh + OpenObserve/OTel Collector, een moderne rootless vervanger van Security
Onion + ELK. Bewaakte infrastructuur is mijn eigen thuisnetwerk in plaats van
een wegwerp-labje. Dashboard is Wazuh's eigen UI (OpenSearch Dashboards, een
Kibana-fork).

## Componenten

1. **UniFi-netwerk**, syslog: firewall/IPS-logs, DHCP-logs
2. **Container "linux-server"**, Wazuh-agent: SSH-auth, File Integrity Monitoring
3. **Container "web-app"**, Wazuh-agent + nginx: access-logs, vulnerability-detectie

Alerts: brute-force SSH, FIM-wijziging.

## Keuze: OpenObserve i.p.v. SigNoz

Twijfel gehad tussen SigNoz en OpenObserve voor de niet-security telemetrie.
OpenObserve wint het op integratiegemak en efficiëntie: één binary tegenover
SigNoz's ClickHouse + query-service + frontend, en dat weegt zwaarder naast
Wazuh's toch al zware indexer op één laptop.

## Draaien

```bash
sudo pacman -S --needed podman podman-compose   # CachyOS
brew install podman-compose                     # Bazzite, podman zit er al in

cd compose
./setup.sh      # start, print bij eerste run de wachtwoorden
./restart.sh
./stop.sh       # --wipe ruimt ook volumes/certs/.env op
```

Wachtwoorden staan in `.env` (git-genegeerd, aangemaakt vanuit `.env.example`).
