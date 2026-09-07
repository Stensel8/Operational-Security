#!/usr/bin/env bash
#
# One-time prep for the Wazuh stack:
#   1. TLS certificates       (Wazuh's own generator container)
#   2. internal_users.yml     (bcrypt hashes of the .env passwords)
#   3. wazuh.yml              (the Wazuh API password)
#
# Reads compose/wazuh/.env. Re-run it after changing a password there.
#
set -euo pipefail
cd "$(dirname "$0")"

[ -f .env ] || { echo "compose/wazuh/.env is missing — copy it from .env.example"; exit 1; }
set -a; . ./.env; set +a

# 1. TLS certificates -------------------------------------------------------
if [ -f config/wazuh_indexer_ssl_certs/root-ca.pem ]; then
    echo "certs: already present"
else
    mkdir -p config/wazuh_indexer_ssl_certs
    podman compose -f generate-indexer-certs.yml run --rm generator
fi

# 2 + 3. Render the credential files from templates ------------------------
# hash.sh prints a bcrypt hash for one password; run it in the indexer image.
bcrypt() {
    podman run --rm docker.io/wazuh/wazuh-indexer:4.14.7 \
        bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh -p "$1" | tail -1
}

echo "rendering internal_users.yml + wazuh.yml from .env"
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

echo "Wazuh prepared."
