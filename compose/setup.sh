#!/usr/bin/env bash
#
# Start the SOC lab on a rootless Podman host. Safe to run again — each step
# skips itself if it's already done.
#
set -euo pipefail
cd "$(dirname "$0")"

# The Wazuh indexer (OpenSearch) refuses to start if this kernel setting is low.
if [ "$(sysctl -n vm.max_map_count)" -lt 262144 ]; then
    echo "vm.max_map_count is too low. Fix it once, as root:"
    echo "  echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-operational-security.conf"
    echo "  sudo sysctl --system"
    exit 1
fi

# First run: seed each .env from its committed example. The placeholder
# passwords work as-is, but are meant to be changed — see the summary below.
for d in wazuh observability; do
    [ -f "$d/.env" ] || { cp "$d/.env.example" "$d/.env"; echo "created $d/.env"; }
done

# Shared network so the collector can reach wazuh.manager by name.
podman network exists operational-security || podman network create operational-security

# Wazuh: TLS certificates + render internal_users.yml / wazuh.yml from wazuh/.env
bash wazuh/prepare.sh

( cd wazuh         && podman compose up -d )
( cd observability && podman compose up -d )

# Read the values back so this summary always matches what is actually running.
set -a; . wazuh/.env; . observability/.env; set +a
cat <<EOF

  Started. The indexer needs ~30s more before the dashboard works.

    Wazuh dashboard   https://localhost:8443    admin / ${WAZUH_INDEXER_PASSWORD}
    Wazuh API         https://localhost:55000   wazuh-wui / ${WAZUH_API_PASSWORD}
    OpenObserve       http://localhost:5080     ${OPENOBSERVE_ROOT_USER_EMAIL} / ${OPENOBSERVE_ROOT_USER_PASSWORD}

  Change those in compose/wazuh/.env and compose/observability/.env, then re-run.
  Stop with ./stop.sh   ·   bounce with ./restart.sh
EOF
