#!/usr/bin/env bash
#
# Stop het SOC-lab. Je data (de named volumes) blijft staan, dus ./setup.sh
# brengt alles weer terug. Geef --wipe mee om ook de data, het netwerk en elk
# gegenereerd bestand (certificaten, gerenderde configs, .env) te verwijderen.
#
set -euo pipefail
cd "$(dirname "$0")"
. ./engine.sh

( cd observability && "$ENGINE" compose down )
( cd wazuh         && "$ENGINE" compose down )

if [ "${1:-}" = "--wipe" ]; then
    ( cd observability && "$ENGINE" compose down -v )
    ( cd wazuh         && "$ENGINE" compose down -v )
    "$ENGINE" network rm operational-security 2>/dev/null || true
    # de certificaatbestanden zijn eigendom van container-UID's (root bij Docker,
    # een gemapte UID bij rootless Podman) — opruimen via een wegwerpcontainer
    # werkt in beide gevallen, zie engine.sh.
    mkdir -p wazuh/config/wazuh_indexer_ssl_certs
    rm_as_container "$(pwd)/wazuh/config/wazuh_indexer_ssl_certs"
    rm -f wazuh/config/wazuh_indexer/internal_users.yml
    rm -f wazuh/config/wazuh_dashboard/wazuh.yml
    rm -f wazuh/.env observability/.env
    echo "Gewist: volumes, netwerk, certificaten, gerenderde configs, .env. Volgende ./setup.sh begint schoon."
fi
