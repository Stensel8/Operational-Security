#!/usr/bin/env bash
#
# Start het SOC-lab op een rootless Podman-host. Veilig om opnieuw te draaien,
# elke stap slaat zichzelf over als hij al gedaan is.
#
set -euo pipefail
cd "$(dirname "$0")"

# De Wazuh indexer (OpenSearch) weigert te starten als deze kernelinstelling te laag is.
if [ "$(sysctl -n vm.max_map_count)" -lt 262144 ]; then
    echo "vm.max_map_count staat te laag. Eenmalig oplossen, als root:"
    echo "  echo 'vm.max_map_count=262144' | sudo tee /etc/sysctl.d/99-operational-security.conf"
    echo "  sudo sysctl --system"
    exit 1
fi

# Eerste run: elke .env aanmaken vanuit het gecommitte voorbeeld. De placeholder-
# wachtwoorden werken direct, maar zijn bedoeld om aan te passen, zie de samenvatting hieronder.
for d in wazuh observability; do
    [ -f "$d/.env" ] || { cp "$d/.env.example" "$d/.env"; echo "$d/.env aangemaakt"; }
done

# Gedeeld netwerk zodat de collector wazuh.manager op naam kan bereiken.
podman network exists operational-security || podman network create operational-security

# Wazuh: TLS-certificaten + internal_users.yml / wazuh.yml renderen vanuit wazuh/.env
bash wazuh/prepare.sh

( cd wazuh         && podman compose up -d )
( cd observability && podman compose up -d )

# Waarden opnieuw inlezen zodat deze samenvatting altijd klopt met wat er echt draait.
set -a; . wazuh/.env; . observability/.env; set +a
cat <<EOF

  Gestart. De indexer heeft nog ~30s nodig voordat het dashboard werkt.

    Wazuh dashboard   https://localhost:8443    admin / ${WAZUH_INDEXER_PASSWORD}
    Wazuh API         https://localhost:55000   wazuh-wui / ${WAZUH_API_PASSWORD}
    OpenObserve       http://localhost:5080     ${OPENOBSERVE_ROOT_USER_EMAIL} / ${OPENOBSERVE_ROOT_USER_PASSWORD}

  Pas deze aan in compose/wazuh/.env en compose/observability/.env, en draai opnieuw.
  Stoppen met ./stop.sh   ·   herstarten met ./restart.sh
EOF
