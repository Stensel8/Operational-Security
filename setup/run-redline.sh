#!/usr/bin/env bash
# Redline is Windows-only (.NET WinForms, FireEye/Mandiant) en .mans-bestanden
# hebben geen Linux-viewer. Dit script zet een losse Wine-prefix op in
# ../state/wine-redline (niet in git), installeert Redline daarin (i.p.v. een
# losse Windows-VM) en zet een GNOME-snelkoppeling klaar die rechtstreeks naar
# DIT script wijst — geen apart gegenereerd wrapper-scriptje, dus geen twee
# plekken die uiteen kunnen gaan lopen.
#
# Alle stappen hieronder (wineprefix, .NET, Redline-install, GNOME-snelkoppeling,
# HiDPI/Wayland-fix) gebeuren automatisch — je hoeft dit script maar één keer te
# draaien. Wil je iets anders (ander .mans-bestand, andere snelkoppeling-naam),
# pas dan de variabelen hieronder aan en run het script opnieuw; het overschrijft
# alleen wat nodig is en slaat installatiestappen over die al gedaan zijn.
#
# Gebruik:
#   ./run-redline.sh                     # installeert/herstelt + opent de .mans
#   ./run-redline.sh pad/naar/iets.mans   # idem, met een ander .mans-bestand
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export WINEPREFIX="$REPO_ROOT/state/wine-redline"
REDLINE_EXE='C:\Program Files (x86)\Redline\Redline.exe'
MANS_FILE="${1:-$REPO_ROOT/Operational Security - Assignments/Redline Investigation.mans}"
# Pas dit pad aan naar waar je het installer-bestand uit Investigation.zip hebt staan
REDLINE_MSI="${REDLINE_MSI:-$REPO_ROOT/Operational Security - Assignments/Redline-1.20.2.msi}"

# Forceert Wine's eigen Wayland-driver i.p.v. XWayland voor ALLE wine-aanroepen
# hieronder (ook wineboot/winetricks/msiexec/winepath). Dit moet helemaal vooraan
# staan: als ook maar één wine-aanroep in deze prefix nog met DISPLAY gezet
# draait, pint dat de interne Wine-desktopsessie op de X11-driver, en crasht de
# latere Wayland-launch alsnog met "nodrv_CreateWindow / explorer process failed
# to start" — ook al wordt DISPLAY daar zelf wel weggehaald.
unset DISPLAY
# Eventuele al draaiende wineserver voor deze prefix (met een oude driver-staat)
# eerst opruimen, zodat we altijd met een schone, consistente Wayland-sessie starten.
wineserver -k 2>/dev/null || true

if [ ! -d "$WINEPREFIX" ]; then
    echo "==> Wineprefix aanmaken in $WINEPREFIX"
    wineboot --init
fi

if ! find "$WINEPREFIX/drive_c" -iname "Redline.exe" 2>/dev/null | grep -q .; then
    echo "==> .NET Framework 4.0 + corefonts installeren (eenmalig, duurt een paar minuten)"
    winetricks --unattended dotnet40 corefonts

    echo "==> Redline installeren vanuit $REDLINE_MSI"
    # Dit haakt vanzelf in op xdg-desktop-menu: Wine registreert hierbij ook al
    # een GNOME-snelkoppeling + icoon, alleen verwijst die naar een kapotte
    # .lnk-shortcut (zie hieronder waarom we 'm overschrijven).
    wine msiexec /i "$REDLINE_MSI" /qn "/L*v" "$REPO_ROOT/state/redline-install.log"
fi

echo "==> GNOME-snelkoppeling installeren/bijwerken"
# Wine's eigen snelkoppeling (uit de MSI-install hierboven) roept Redline aan
# via een .lnk-bestand, en dat lost Wine niet betrouwbaar op (opent soms
# gewoon niks). Daarom wijst onze snelkoppeling rechtstreeks naar DIT script
# (Exec=<pad-naar-dit-script>) — dus geen los wrapper-bestand nodig, en
# klikken op het icoon doet exact hetzelfde als dit script handmatig draaien.
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
DESKTOP_DIR="$HOME/.local/share/applications/wine/Programs/Redline"
DESKTOP_FILE="$DESKTOP_DIR/Redline.desktop"
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=Redline
Comment=FireEye/Mandiant Redline (via Wine) - Incident Response analyse
Exec=$SCRIPT_PATH
Type=Application
StartupNotify=true
Path=$WINEPREFIX/drive_c/Program Files (x86)/Redline/
Icon=6007__0FEB29C173F28D6B93055C.0
StartupWMClass=redline.exe
Categories=Utility;Security;
EOF
if ! desktop-file-validate "$DESKTOP_FILE" 2>&1; then
    echo "WAARSCHUWING: $DESKTOP_FILE is niet geldig volgens desktop-file-validate" >&2
fi
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

echo "==> Redline starten met $MANS_FILE"
wine "$REDLINE_EXE" "$(winepath -w "$MANS_FILE")"
