# SIEMs and SOCs — building a Security Operations Center

Project for the **Operational Security** module (Saxion, IT Security 2025–2026).
The assignment asks for a SIEM built with Security Onion + the ELK stack on
Windows Server / Ubuntu. This repo does the same job on a stack that reflects how
detection infrastructure is actually built today:

| Layer | Tool | Why |
|---|---|---|
| SIEM engine | **Wazuh 4.14** (manager + indexer + dashboard) | decoders, correlation rules, MITRE ATT&CK, FIM, SCA — the real SIEM work |
| Observability / pipeline health | **OpenObserve** | OTLP-native, single binary, ad-hoc search over the detection pipeline itself |
| Collection | **OpenTelemetry Collector** (contrib) | vendor-neutral (CNCF) collection layer instead of Elastic Beats / Logstash |
| Runtime | **rootless Podman** on Fedora, SELinux enforcing | no root daemon; a container escape lands on an unprivileged user, not root |

> **Why not SigNoz?** It is a nice observability UI, but it dropped its
> maintained Compose file for "Foundry", which is Docker-first with no rootless
> Podman path. OpenObserve fills the same slot with a plain Compose file. See
> [`docs/setup-notes.md`](docs/setup-notes.md).

## Layout

```
compose/
  setup.sh                  start   (network + certs + rendered creds + both stacks)
  stop.sh                   stop    (--wipe also deletes volumes, network, generated files)
  restart.sh                bounce every container
  wazuh/
    docker-compose.yml      Wazuh single-node, adapted for rootless Podman
    prepare.sh              TLS certs + renders internal_users.yml / wazuh.yml from .env
    .env.example            passwords (placeholder values) — copy to .env
    config/                 Wazuh manager / indexer / dashboard config (+ templates)
  observability/
    compose.yaml            OpenObserve + OpenTelemetry Collector
    otelcol/config.yaml     receivers (OTLP, filelog) -> exporter (OpenObserve)
    .env.example            OpenObserve credentials — copy to .env
docs/
  setup-notes.md            running build log — what broke and how it was fixed
```

## Credentials

Every credential lives in a git-ignored `.env` file; only `.env.example` (with
`Please-Change-Me-Before-Deploying` placeholders) is committed. `setup.sh` seeds
`.env` from the example on first run and prints the effective values at the end.

## Quick start (rootless Podman)

```bash
cd compose
./setup.sh            # start   (creates the network, certs and .env on first run)
./restart.sh          # bounce every container
./stop.sh             # stop    (--wipe wipes everything)
```

`setup.sh` is ~30 lines of plain commands — read it top to bottom, it is the
whole story. Re-running it is safe; it skips whatever is already done.

## Status

- [x] Wazuh single-node running rootless (indexer cluster green, dashboard up, API up)
- [x] OpenObserve + OpenTelemetry Collector running rootless
- [x] Pipeline proven: JSON event on host → Collector → OpenObserve (queryable)
- [x] Detection proven: SSH brute-force line → Wazuh rule 5710 → MITRE T1110.001 / T1021.004
- [x] All credentials via `.env`, only `.env.example` committed
- [ ] Wazuh `alerts.json` → Collector → OpenObserve (single pane)
- [ ] Endpoint agents on a monitored target (Power2Music case)
- [ ] Detection-as-code: Sigma rules in git, validated with Atomic Red Team
