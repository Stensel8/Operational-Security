#!/usr/bin/env bash
#
# Stop het SOC-lab. Je data (de named volumes) blijft staan, dus ./setup.sh
# brengt alles weer terug. Geef --wipe mee om ook de data, het netwerk en elk
# gegenereerd bestand (certificaten, gerenderde configs, .env) te verwijderen.
#
set -euo pipefail
cd "$(dirname "$0")"

( cd observability && podman compose down )
( cd wazuh         && podman compose down )

if [ "${1:-}" = "--wipe" ]; then
    ( cd observability && podman compose down -v )
    ( cd wazuh         && podman compose down -v )
    podman network rm operational-security 2>/dev/null || true
    # de certificaatbestanden zijn eigendom van container-UID's, dus verwijderen binnen de userns
    podman unshare rm -rf wazuh/config/wazuh_indexer_ssl_certs
    rm -f wazuh/config/wazuh_indexer/internal_users.yml
    rm -f wazuh/config/wazuh_dashboard/wazuh.yml
    rm -f wazuh/.env observability/.env
    echo "Gewist: volumes, netwerk, certificaten, gerenderde configs, .env. Volgende ./setup.sh begint schoon."
fi
