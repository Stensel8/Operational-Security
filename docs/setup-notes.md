# Setup notes

Running build log. Newest entries at the bottom. The point of this file is the
"evaluate what went wrong or well" part of the assignment — so the dead ends stay
in.

## Choices

- **Host:** Fedora, rootless Podman 5.8, cgroups v2, SELinux **enforcing**,
  netavark. Rootless is the security argument for this module: no root daemon, a
  container escape lands on an unprivileged user instead of root on the host.
- **SIEM:** Wazuh 4.14.7 (stable; 5.x is still beta on Docker Hub). It is the only
  open-source tool that is an actual SIEM — decoders, correlation, MITRE ATT&CK,
  FIM, SCA. GPLv2, no feature-gating.
- **Observability layer:** OpenObserve. Originally wanted SigNoz (nicer UI, MIT
  core) but SigNoz deprecated its Compose file for "Foundry", which shells out to
  `docker` and has no rootless Podman path. OpenObserve ships a plain maintained
  Compose file and runs rootless as one container. AGPL-3.0.
- **Collection:** OpenTelemetry Collector (contrib) instead of Elastic Beats /
  Logstash — vendor-neutral, CNCF, and the same collector handles files, journald,
  syslog and OTLP.

## Build log

### 1. Environment probe

```
podman 5.8.4 / rootless=true / SELinux=Enforcing
net.ipv4.ip_unprivileged_port_start = 1024
vm.max_map_count = 2147483642     # already high enough for the indexer
28 GB RAM, subuid/subgid range 524288+65536
```

### 2. Observability stack — worked almost first try

`compose/observability/`. OpenObserve + OTel Collector on an external
`operational-security` network. Collector config: `otlp` + `file_log/security`
receivers → `resource_detection` → `otlp_http` exporter to
`http://openobserve:5080/api/default`, authenticated with the `basicauth`
extension (username/password from the container env, no base64 in a file).

Gotchas:
- otelcol 0.160 renamed components to snake_case: `otlphttp`→`otlp_http`,
  `filelog`→`file_log`, `resourcedetection`→`resource_detection`. Old names log a
  deprecation warning. Config uses the new names.
- OpenObserve `_search` API rejects `start_time: 0` with "invalid time range" —
  pass real microsecond epochs.

Smoke test — dropped a JSON line into `observability/logs/` and queried it back:

```
POST /api/default/_search  ->  1 hit
  event=test.pipeline  rule_id=0000  severity_text=INFO  host_name=<collector>
```

Pipeline confirmed: host file → Collector (json_parser) → OpenObserve, fields
flattened and searchable.

### 3. Wazuh single-node — rootless friction

Based on `wazuh/wazuh-docker` `v4.14.7` `single-node/`. Adaptations in
`compose/wazuh/docker-compose.yml`:

Cert generation stays native: `prepare.sh` runs Wazuh's own
`generate-indexer-certs.yml` with `podman compose ... run --rm generator`. The
official generator image sets the right owner UIDs on the keys itself
(indexer/dashboard → 1000, manager → 999) — the `find: command not found` it
logs is not fatal. `prepare.sh` then renders `internal_users.yml` and
`wazuh.yml` from `wazuh/.env` (see §6).

| Problem | Fix |
|---|---|
| `podman compose` (podman-compose 1.6) hung pulling 3 large images at once | pull images explicitly first, then `up` |
| ports 514/udp and 443 are privileged, rootless can't bind them | remapped to `5514/udp` and `8443` |
| `memlock: -1` ulimit — rootless can't set RLIMIT_MEMLOCK unlimited | removed; the 4.14 indexer doesn't `mlockall` |
| indexer/dashboard: `AccessDeniedException` reading `opensearch.yml`, certs, etc. | bind mounts need an SELinux label — added `:z` to every host bind mount |
| with `:Z` (private label) the indexer and dashboard each restarted 2× — they share `root-ca.pem` and each `:Z` relabels it privately, so one loses the race | use `:z` (shared label) for files mounted by more than one container |

Result — clean start, 0 restarts:

```
wazuh.indexer   cluster status: green, 1 node
wazuh.dashboard https://localhost:8443  (HTTP 200)
wazuh.manager   API issues JWT on /security/user/authenticate
                filebeat harvester started on /var/ossec/logs/alerts/alerts.json
```

### 4. Detection works — `wazuh-logtest`

Fed one SSH brute-force line through the manager:

```
Sep  7 21:30:01 web01 sshd[41213]: Failed password for invalid user admin from 203.0.113.66 port 55001 ssh2

Phase 2 (decode):  srcip=203.0.113.66  srcuser=admin
Phase 3 (rule):    id=5710  level=5  "sshd: Attempt to login using a non-existent user"
                   mitre.id       = T1110.001, T1021.004
                   mitre.tactic   = Credential Access, Lateral Movement
                   also mapped: PCI-DSS 10.2.4/5, HIPAA 164.312.b, NIST AU.14/AC.7, GDPR
**Alert to be generated.
```

### 5. Small things

- **OpenObserve UI shows Dutch.** The language is a per-browser setting (stored in
  localStorage), picked up from `navigator.language` on first visit. There is no
  server-side or env-var override. Fix once per browser: profile menu (top-right)
  → Language → English. It sticks after that.
- **Image versions are pinned**, not `:latest` (`openobserve:v0.92.2`,
  `opentelemetry-collector-contrib:0.160.0`, `wazuh-*:4.14.7`,
  `wazuh-certs-generator:0.0.4`). Renovate covers every image: the two compose
  files by default, and `generate-indexer-certs.yml` because `renovate.json`
  adds it to the docker-compose manager's file list. Dependabot is scoped to
  GitHub Actions only, so the two tools never PR the same thing.

### 6. All credentials via .env

Every password lives in a git-ignored `.env` next to the compose file it belongs
to; only `.env.example` (placeholder `Please-Change-Me-Before-Deploying-1!`) is
committed. Compose reads `.env` for `${VAR:?}` interpolation. Any value works —
the placeholder is just a visible default.

Wazuh keeps credentials in three places, so `prepare.sh` does the plumbing:
`WAZUH_INDEXER_PASSWORD` and `WAZUH_DASHBOARD_PASSWORD` are bcrypt-hashed (via the
indexer image's `hash.sh`) into `internal_users.yml`; `WAZUH_API_PASSWORD` goes
into `wazuh.yml`; all three are passed to the manager/dashboard containers.

Gotchas:
- **OpenObserve rejects weak passwords** — needs 8–128 chars with lower, upper,
  digit and a special char. The first placeholder (`Please-Change-Me-Before-Deploying`)
  had no digit and OpenObserve crash-looped 9× before this was caught. Hence the
  `-1!` suffix.
- **Changing a Wazuh password needs a volume wipe.** OpenSearch initialises its
  user database from `internal_users.yml` only once, into the `.opendistro_security`
  index. If the indexer volume already exists, the new hash is ignored and auth
  fails. `./stop.sh --wipe` then `./setup.sh`.

## TODO

- Forward Wazuh `alerts.json` → OTel Collector → OpenObserve (single pane).
- Wazuh agent on a monitored host (the Power2Music case: a Linux box + a Windows box).
- Sigma rules in git, converted in CI, validated by running Atomic Red Team tests
  and scoring ATT&CK coverage.
- Convert the Compose files to Quadlet units so the stack starts on boot via
  systemd (`loginctl enable-linger`).
