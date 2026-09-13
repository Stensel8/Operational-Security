#!/usr/bin/env bash
#
# Herstart elke container. Snel, behoudt alle data. Gebruik dit als iets vastloopt.
# Compose- of configbestand aangepast? Gebruik ./setup.sh, dat herschept wat gewijzigd is.
#
set -euo pipefail
cd "$(dirname "$0")"

for d in wazuh observability; do
    ( cd "$d" && podman compose stop && podman compose start )
done

echo "Herstart. De indexer heeft nog ~30s nodig voordat het dashboard werkt."
