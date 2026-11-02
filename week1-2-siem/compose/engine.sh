# Gedeeld door setup.sh/restart.sh/stop.sh/wazuh/prepare.sh: detecteert of je
# Docker of (rootless) Podman gebruikt, zodat deze scripts op beide werken
# zonder dat je zelf iets hoeft te kiezen. `source` dit bestand, gebruik
# daarna $ENGINE in plaats van een hardgecodeerde "docker"/"podman".
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
    ENGINE=docker
elif command -v podman >/dev/null 2>&1; then
    ENGINE=podman
else
    echo "Geen docker of podman gevonden (of de Docker-daemon draait niet)." >&2
    exit 1
fi

# docker heeft geen "network exists"-subcommando zoals podman; dit vangt het verschil op.
network_exists() {
    if [ "$ENGINE" = docker ]; then
        docker network inspect "$1" >/dev/null 2>&1
    else
        podman network exists "$1"
    fi
}

# Verwijdert bestanden die door een container zijn weggeschreven, ook als ze
# root-eigendom zijn (Docker) of aan een gemapte UID horen (rootless Podman) —
# door de verwijdering zelf in een wegwerpcontainer te doen werkt dit sowieso,
# in plaats van `podman unshare rm -rf` (Podman-only) of `sudo rm -rf`.
rm_as_container() {
    "$ENGINE" run --rm -v "$1":/target:Z docker.io/library/alpine:3 sh -c 'rm -rf /target/*'
}
