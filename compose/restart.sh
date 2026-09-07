#!/usr/bin/env bash
#
# Bounce every container. Quick, keeps all data. Use it when something is stuck.
# Changed a compose or config file? Use ./setup.sh — it recreates what changed.
#
set -euo pipefail
cd "$(dirname "$0")"

for d in wazuh observability; do
    ( cd "$d" && podman compose stop && podman compose start )
done

echo "Restarted. The indexer needs ~30s before the dashboard works."
