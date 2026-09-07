#!/usr/bin/env bash
#
# Stop the SOC lab. Your data (the named volumes) is kept, so ./setup.sh brings
# everything back. Pass --wipe to also delete the data, network and every
# generated file (certs, rendered configs, .env).
#
set -euo pipefail
cd "$(dirname "$0")"

( cd observability && podman compose down )
( cd wazuh         && podman compose down )

if [ "${1:-}" = "--wipe" ]; then
    ( cd observability && podman compose down -v )
    ( cd wazuh         && podman compose down -v )
    podman network rm operational-security 2>/dev/null || true
    # the cert files are owned by container UIDs, so remove them inside the userns
    podman unshare rm -rf wazuh/config/wazuh_indexer_ssl_certs
    rm -f wazuh/config/wazuh_indexer/internal_users.yml
    rm -f wazuh/config/wazuh_dashboard/wazuh.yml
    rm -f wazuh/.env observability/.env
    echo "Wiped: volumes, network, certs, rendered configs, .env — next ./setup.sh starts fresh."
fi
