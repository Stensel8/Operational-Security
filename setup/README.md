# Setup: Redline draaien op Linux (CachyOS)

Redline (FireEye/Mandiant) is Windows-only, en `.mans`-bestanden (Mandiant
Analysis Session) hebben geen Linux-equivalent dat ze native opent. In plaats
van een losse Windows-VM draai ik Redline via Wine, geïnstalleerd als een
normale GNOME-app met eigen icoon in het applicatiemenu — geen los scriptje
dat je handmatig moet opstarten.

## Snelste pad: gewoon het script draaien

```bash
./run-redline.sh
```

Dat is het. [`run-redline.sh`](run-redline.sh) doet alle stappen hieronder
automatisch, in deze volgorde, en alleen de stappen die nog nodig zijn
(herdraaien is dus goedkoop):

1. wineprefix aanmaken (`../state/wine-redline`, niet in git) als die nog niet bestaat
2. .NET Framework 4.0 + corefonts installeren (eenmalig, duurt een paar minuten)
3. Redline installeren vanuit de MSI
4. Een werkende GNOME-snelkoppeling wegschrijven (met de Wayland-fix erin, zie
   verderop — Wine's eigen snelkoppeling uit de MSI-install werkt namelijk niet)
5. Redline openen met het `.mans`-bestand

Na de eerste run staat Redline gewoon in het GNOME-applicatiemenu (zoek op
"Redline") en werkt die snelkoppeling precies zoals een native Linux-app: 1x
klikken, en 'm staat open met de investigatie geladen. Niet perfect (zie
hieronder), maar prima bruikbaar.

De rest van dit document legt uit **wat** het script doet en **waarom** —
handig als je zelf iets wil tweaken (ander `.mans`-bestand, andere
snelkoppeling-naam, debuggen als iets niet werkt).

## Waarom dit op CachyOS goed gaat

Ik draai [CachyOS](https://cachyos.org/), een Arch-gebaseerde distro die vrij
zwaar geoptimaliseerd is voor emulatie en translation-layers (het is vooral
bekend van gaming-performance, maar dat raakt precies dezelfde tooling die
Wine nodig heeft): een CachyOS-specifieke kernel met schedulers die gericht
zijn op lage latency voor dit soort workloads, en eigen gepatchte builds van
Wine (`wine-cachyos-opt`) en Proton (`proton-cachyos-slr`) naast de normale
`wine`-package uit Arch. Daardoor staat er op dit systeem al veel klaar
(wine, winetricks, meerdere wine-builds, protontricks) zonder dat ik er zelf
iets voor hoefde te installeren — een "kale" Linux-distro had hier meer
handwerk gekost. Voor deze opdracht was de standaard `wine`-package (11.21)
overigens voldoende; Redline is een lichte .NET WinForms-app, geen zware
3D-applicatie, dus de gaming-geoptimaliseerde builds voegen hier weinig toe.
Kortom: het werkt hier niet geweldig (zie de kanttekeningen hieronder), maar
voor een stuk legacy Windows-software uit 2017 opzich best verrassend goed.

## Stap 1-3: wineprefix + .NET + Redline installeren

```bash
# Uitgevoerd vanuit setup/ (deze map)
export WINEPREFIX="$(pwd)/../state/wine-redline"

# .NET Framework 4.0 ontbreekt in een kale prefix; Redline is een .NET WinForms-app
winetricks --unattended dotnet40 corefonts

# Installeert Redline zelf + registreert 'm automatisch in het GNOME-appmenu
wine msiexec /i "../Operational Security - Assignments/Redline-1.20.2.msi" /qn "/L*v" "../state/redline-install.log"
```

Dat `msiexec /i` alleen is al genoeg om Redline als app in GNOME te laten
verschijnen: Wine haakt standaard in op `xdg-desktop-menu`, dus elke
Start Menu-snelkoppeling die de MSI aanmaakt, verschijnt automatisch in
GNOME's app-overzicht met het juiste icoon (zie
`~/.local/share/applications/wine/Programs/Redline/`). Er is dus geen
aparte actie nodig om het "als Linux-app" te laten voelen — dat gebeurt
vanzelf bij de install. Het probleem zit 'm in wat die snelkoppeling precies
aanroept (zie stap 4).

## Stap 4: de GNOME-snelkoppeling écht laten werken

Wine's eigen snelkoppeling uit de MSI-install roept Redline aan via een
`.lnk`-bestand (`...\Start Menu\Programs\Redline\Redline.lnk`). Dat lost Wine
niet betrouwbaar op: aanklikken geeft een laad-cursor en dan gebeurt er niks,
zowel vanuit GNOME als wanneer je het `.lnk`-bestand handmatig aanroept.
`Redline.exe` rechtstreeks aanroepen werkt wel altijd. Het script overschrijft
daarom `~/.local/share/applications/wine/Programs/Redline/Redline.desktop`
met een eigen versie waarvan de `Exec=`-regel gewoon rechtstreeks naar
[`run-redline.sh`](run-redline.sh) zelf wijst. Geen los wrapper-scriptje dus:
klikken op het icoon in GNOME doet exact hetzelfde als dit script handmatig
draaien (dat script installeert niks opnieuw als het al klaarstaat, het
schrijft alleen de laatste stap — Redline openen — opnieuw uit).

Let op: de `Exec=`-regel van een `.desktop`-bestand ondersteunt geen
shell-syntax (geen `;`, geen losse enkele quotes) — vandaar dat dit naar een
los script wijst in plaats van een inline commando met `unset DISPLAY; wine
...` erin. Dat laatste lijkt te werken, maar `desktop-file-validate` wijst
'm af en GNOME weigert 'm dan ook gewoon stilletjes te starten.

## HiDPI/Wayland: scherp krijgen

Dit was het enige echte obstakel. Standaard draait Wine via XWayland
(X11-compatibiliteitslaag onder Wayland). Op een HiDPI-scherm met
fractionele GNOME-schaling (hier 133%) past XWayland die schaling niet goed
toe op oude, niet-DPI-aware apps zoals Redline (een 2017-app): het resultaat
is piepklein én wazig tegelijk, ook met een virtueel Wine-bureaublad erbij
(dat loopt namelijk ook via dezelfde XWayland-laag).

Oplossing: Wine's eigen (experimentele) Wayland-driver forceren in plaats
van XWayland, door simpelweg `DISPLAY` weg te halen uit de omgeving — Wine
kiest dan automatisch de Wayland-driver zodra alleen `WAYLAND_DISPLAY`
beschikbaar is:

```bash
unset DISPLAY
wine "C:\Program Files (x86)\Redline\Redline.exe" <pad-naar-.mans>
```

Let op: `env -u DISPLAY wine ...` (als één commando, zonder losse `unset`)
bleek hier onbetrouwbaar — soms werkt het, soms doet het stilletjes niks. Doe
het als twee losse stappen zoals hierboven. En: zodra er ook maar één keer
een wine-commando in deze prefix draait terwijl `DISPLAY` nog wél gezet is
(bijvoorbeeld `winepath` of `wineboot` per ongeluk vóór de `unset`), pint dat
de interne Wine-sessie alsnog op de X11-driver — de latere Wayland-launch
crasht dan alsnog met `nodrv_CreateWindow / explorer process failed to
start`. Daarom staat `unset DISPLAY` in [`run-redline.sh`](run-redline.sh)
helemaal bovenaan, vóór welke wine-aanroep dan ook, met een `wineserver -k`
erachteraan om een eventuele al draaiende wineserver met de verkeerde
driver-status op te ruimen.

Resultaat: scherpe tekst, correcte venstergrootte, native Wayland-rendering.
De blauwe titelbalk die je dan nog ziet is geen bug — dat is Wine's eigen
minimale client-side decoration (Wayland geeft geen server-side decorations
aan niet-native apps), en de rest van de UI (rode/witte vlakken, knoppen)
is gewoon Redline's eigen Windows XP/Vista-achtige uiterlijk uit 2017. Dat
hoort zo; het is geen Wine-glitch om te fixen. Dit is ook meteen de grens
van wat hier haalbaar is: het werkt goed genoeg om prettig mee te werken en
te screenshotten, maar het voelt nooit voor 100% als een native app — je
ziet gewoon dat het een oude Windows-applicatie is die hier draait.

## Stap 5 / herhaalbaar opstarten

```bash
unset DISPLAY
wine "C:\Program Files (x86)\Redline\Redline.exe" <pad-naar-.mans>
```

Of gewoon nogmaals [`run-redline.sh`](run-redline.sh) draaien, of de
GNOME-snelkoppeling (zoek "Redline") gebruiken nadat het script eenmaal is
gedraaid.

## Nog een gotcha: Redline overschrijft je `.mans`-bestand

Zodra je een `.mans` in Redline opent, zet Redline 'm om naar zijn eigen
interne SQLite-cache — van een nette ~840 KB zip naar een paar MB groot
SQLite-bestand. Werk dus met een kopie, of pak 'm opnieuw uit
`Investigation.zip` als je 'm per ongeluk kwijt bent.

## Redline eigenlijk niet nodig: `investigate_mans.py`

Redline zelf bleef (ook met alle fixes hierboven) af en toe gewoon vastlopen
tijdens het navigeren door een grote `.mans`. Een `.mans` is onder de
motorkap simpelweg een zip met XML-auditbestanden (zie `manifest.json`
erin) — exact dezelfde data die Redline's UI toont, alleen zonder de
crashende GUI ertussen. [`investigate_mans.py`](investigate_mans.py) pakt
die XML's rechtstreeks uit en doorzoekt ze met een paar simpele regex'en op
verdachte patronen (netwerkverbindingen, bestanden die op een ándere machine
worden weggeschreven, de DNS-cache):

```bash
./investigate_mans.py
# of: ./investigate_mans.py pad/naar/een/ander.mans
```

Geen Wine, geen GUI, geen gecrash — gewoon Python + de standaardbibliotheek.
