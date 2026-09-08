# SIEMs and SOCs — Security Operations Center

My project for the **Operational Security** module/lessons (Saxion, IT Security 2025–2026).
The assignment originally asks for a SIEM (Security Onion + ELK on Windows Server / Ubuntu);
this repo builds the same thing on a current, rootless stack, as I wanted to do something different and be a little more original.

The work is not complete yet.

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


## Credentials

Every credential lives in a git-ignored `.env`; only `.env.example` (placeholder
values) is committed. `setup.sh` sees `.env` on first run and prints the
effective values at the end.

## Status

- [x] Wazuh single-node running rootless (indexer green, dashboard + API up)
- [x] OpenObserve + OpenTelemetry Collector running rootless
