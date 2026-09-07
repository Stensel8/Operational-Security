# SIEMs and SOCs — Security Operations Center

Project for the **Operational Security** module (Saxion, IT Security 2025–2026).
The assignment asks for a SIEM (Security Onion + ELK on Windows Server / Ubuntu);
this repo builds the same thing on a current, rootless stack.

| Layer | Tool |
|---|---|
| SIEM engine | Wazuh 4.14 — manager + indexer + dashboard |
| Observability | OpenObserve (OTLP-native, single binary) |
| Collection | OpenTelemetry Collector (contrib) |
| Runtime | rootless Podman on Fedora, SELinux enforcing |

## Quick start (rootless Podman)

```bash
cd compose
./setup.sh            # start — creates the network, certs and .env on first run
./restart.sh          # bounce every container
./stop.sh             # stop  — --wipe also deletes volumes, network, generated files
```

`setup.sh` is safe to re-run; it skips whatever is already done.

## Layout

```
compose/
  setup.sh / stop.sh / restart.sh   orchestration
  wazuh/          Wazuh single-node, adapted for rootless Podman
  observability/  OpenObserve + OpenTelemetry Collector
```

## Credentials

Every credential lives in a git-ignored `.env`; only `.env.example` (placeholder
values) is committed. `setup.sh` seeds `.env` on first run and prints the
effective values at the end.

## Status

- [x] Wazuh single-node running rootless (indexer green, dashboard + API up)
- [x] OpenObserve + OpenTelemetry Collector running rootless
- [x] Pipeline proven: host JSON event → Collector → OpenObserve
- [x] Detection proven: SSH brute-force → Wazuh rule 5710 → MITRE T1110.001
- [x] All credentials via `.env`, only `.env.example` committed
- [ ] Wazuh `alerts.json` → Collector → OpenObserve (single pane)
- [ ] Endpoint agents on a monitored target
- [ ] Detection-as-code: Sigma rules in git, validated with Atomic Red Team
