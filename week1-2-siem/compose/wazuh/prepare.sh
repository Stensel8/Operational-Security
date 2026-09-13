#!/usr/bin/env bash
#
# Eenmalige voorbereiding van de Wazuh-stack:
#   1. TLS-certificaten       (Wazuh's eigen generator-container)
#   2. internal_users.yml     (bcrypt-hashes van de .env-wachtwoorden)
#   3. wazuh.yml              (het Wazuh API-wachtwoord)
#
# Leest compose/wazuh/.env. Opnieuw draaien nadat je daar een wachtwoord wijzigt.
#
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] || { echo "compose/wazuh/.env ontbreekt, kopieer hem vanuit .env.example"; exit 1; }
set -a; . ./.env; set +a

# 1. TLS-certificaten --------------------------------------------------------
if [ -f config/wazuh_indexer_ssl_certs/root-ca.pem ]; then
    echo "certificaten: al aanwezig"
else
    mkdir -p config/wazuh_indexer_ssl_certs
    podman compose -f generate-indexer-certs.yml run --rm generator
fi

# 2 + 3. Credentialbestanden renderen vanuit templates ----------------------
# hash.sh print een bcrypt-hash voor één wachtwoord; draait in de indexer-image.
bcrypt() {
    podman run --rm docker.io/wazuh/wazuh-indexer:4.14.7 \
        bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p "$1" | tail -1
}

echo "internal_users.yml + wazuh.yml renderen vanuit .env"
ADMIN_HASH=$(bcrypt "$WAZUH_INDEXER_PASSWORD") \
KIBANASERVER_HASH=$(bcrypt "$WAZUH_DASHBOARD_PASSWORD") \
WAZUH_API_PASSWORD="$WAZUH_API_PASSWORD" \
python3 - <<'PY'
import os, pathlib
def render(src, dst, mapping):
    text = pathlib.Path(src).read_text()
    for k, v in mapping.items():
        text = text.replace(k, v)
    pathlib.Path(dst).write_text(text)

render("config/wazuh_indexer/internal_users.yml.template",
       "config/wazuh_indexer/internal_users.yml",
       {"__ADMIN_HASH__": os.environ["ADMIN_HASH"],
        "__KIBANASERVER_HASH__": os.environ["KIBANASERVER_HASH"]})

render("config/wazuh_dashboard/wazuh.yml.template",
       "config/wazuh_dashboard/wazuh.yml",
       {"__WAZUH_API_PASSWORD__": os.environ["WAZUH_API_PASSWORD"]})
PY

echo "Wazuh voorbereid."
