# Week 3-4: Incident Response

Analyse van `Redline Investigation.mans` met Redline (FireEye/Mandiant), een
Windows-only tool die ik via Wine draai (zie [Tooling](#tooling) hieronder) in
plaats van een losse Windows-VM. Rapport beantwoordt de 9 opdrachtvragen uit
de bijgeleverde opdracht.

## Tooling

Redline is een .NET WinForms-app van FireEye/Mandiant, zonder Linux-equivalent
dat `.mans`-bestanden (Mandiant Analysis Session) native opent. In plaats van
een Windows-VM draai ik Redline via Wine, geïnstalleerd als volwaardige
GNOME-app (eigen icoon in het appmenu, niet alleen een los scriptje). Zie
[`../setup/README.md`](../setup/README.md) voor de volledige uitleg
(inclusief de HiDPI/Wayland-rendering-fix) en
[`../setup/run-redline.sh`](../setup/run-redline.sh) voor het herhaalbare
opstartscript.

Eerlijkheidshalve: Redline zelf (een applicatie uit het Windows XP-tijdperk,
voor het laatst bijgewerkt in 2020) bleef ook ná de Wine/Wayland-fixes
regelmatig vastlopen tijdens het doorklikken van een grote `.mans`. Een
`.mans`-bestand is onder de motorkap gewoon een zip met XML-auditbestanden
erin (zie `manifest.json`) — dezelfde data die Redline's UI toont, alleen dan
zonder de crashende GUI ertussen. Ik heb daarom [`../setup/investigate_mans.py`](../setup/investigate_mans.py)
geschreven: een kort Python-scriptje dat die XML's met simpele regex-zoekacties
doorzoekt (verdachte netwerkpatronen, bestanden die op een andere machine
worden weggeschreven, de DNS-cache) en de bevindingen gewoon op het scherm
print. Scheelt een hoop gedoe — zie [`../setup/README.md`](../setup/README.md)
voor hoe je het draait.

Nog een gotcha om te vermelden: Redline overschrijft het `.mans`-bestand zelf
met zijn eigen interne cache zodra je het opent (van een nette ~840 KB
zip-file naar een 6,5 MB SQLite-bestand). Werk dus altijd vanaf een kopie, of
pak 'm opnieuw uit de oorspronkelijke `Investigation.zip` als je 'm kwijt bent.

Net als bij de rest van deze portfolio met AI-assistentie via IDE-integraties:

- Anthropic. (2026). *Claude (Sonnet 5)* [Large language model]. [https://claude.ai](https://claude.ai)
- Mistral AI. (2026). *Mistral Vibe (GLM 5.3)* [Large language model]. [https://mistral.ai](https://mistral.ai)

## 9 opdrachtvragen

Bron: `Investigation.docx` (meegeleverd bij `Redline Investigation.mans`).

1. **Verdachte host** — hostname, IP-adres en poortinformatie van de communicatie?
2. **Verantwoordelijk proces** — welk proces was verantwoordelijk voor deze communicatie?
3. **Child-processen** — heeft dit proces andere processen gespawned die aan de aanvaller toe te schrijven zijn? Zo ja, welke?
4. **Gedropte bestanden** — welke verdachte bestanden heeft de aanvaller gedropt?
5. **Persistence** — hoe heeft de aanvaller persistence op het endpoint tot stand gebracht?
6. **Lateral movement** — zijn er tekenen van lateral movement? Zo ja, beschrijf wat gevonden is.
7. **Data-exfiltratie** — zijn er tekenen van data-exfiltratie? Zo ja, beschrijf wat gevonden is.
8. **SOC-advies** — als SOC-analist, welke acties zou je aanbevelen na het bekijken van dit triage-pakket?
9. **Overige bevindingen** — overige opvallende artefacten of analyse.

## Context

Het getriagede systeem is **VICTIM-5** (IP `192.168.0.152` / `192.168.7.135`,
domein `RESEARCH`, Windows XP SP3, VMware-VM). Dit is duidelijk een
opzettelijk kwetsbaar gemaakte labomgeving — de hostnamen in de DNS-cache
spreken voor zich: naast `victim-5` en `victim-6` staat er ook gewoon een
host die **`attacker-2`** heet (zie vraag 1). Geen productiesysteem dus.

De agent `Mandiant Agent`/`miragent.exe` (FireEye MIR — het systeem waarmee
Redline deze triage-collectie heeft verzameld) draait wél legitiem op de
host en praat met `192.168.7.128` en `192.168.7.11`; dat is gewoon de
MIR-infrastructuur, geen kwaadaardig verkeer. `192.168.7.137` (oftewel
`attacker-2`) hoort daar nadrukkelijk niet bij.

## Antwoorden

### 1. Verdachte host

Geen extern/internet-IP — het gebeurt allemaal binnen hetzelfde interne
netwerk. Twee dingen vallen op:

- **Explorer.EXE** (PID 680) zoekt tweemaal (`00:47:43Z` en `00:48:53Z`) het
  domein **`msoutlookg.com`** op — een naam die aan Microsoft/Outlook doet
  denken — en verbindt daarna 25x met `192.168.7.137` op poort 443 (HTTPS).
  In de DNS-cache van het systeem staat gewoon wat dat domein écht is: een
  CNAME naar een host die **letterlijk `attacker-2` heet**. Geen slimme
  vermomming dus, gewoon een nepnaam die lokaal naar de aanvaller zelf wijst.
- Om `00:52:15Z` pingt het systeem eerst **`192.168.7.136`** (hostnaam
  `victim-6`, ook via de DNS-cache te herleiden) en zet er vlak daarna een
  verbinding mee op via **poort 139** (het "bestanden delen"-protocol SMB).

### 2. Verantwoordelijk proces

**`cmd.exe`** (PID 492) is verantwoordelijk voor de SMB-communicatie naar
VICTIM-6. Volgens de procesinventaris (`ProcessItem`) is de **parent van dit
`cmd.exe` proces 680 — oftewel exact hetzelfde Explorer.EXE** dat de
verdachte DNS-lookups deed. `cmd.exe` draaide onder het account
**`VICTIM-5\Alice_Admin`** en startte om `00:50:24Z`, dus ruim voordat het
actief werd op `00:52:15Z`.

### 3. Child-processen

Geen. `cmd.exe` (PID 492) start zelf geen nieuw proces — het schrijft zelf
rechtstreeks de twee bestanden over het netwerk weg (zie vraag 4), het
start niet nog iets extra's op.

Wel een detail dat opvalt als je naar de handles van `cmd.exe` kijkt: het
proces heeft named pipes open (`\Device\NamedPipe\Win32Pipes.000002a8.*`).
Dat is precies hoe tools als PsExec een `cmd.exe` op afstand bedienen
(in-/output via een pipe in plaats van een echt scherm). Sterke aanwijzing
dus dat dit `cmd.exe` niet door iemand is opgestart die er fysiek/via
RDP achter zat, maar vanaf een ander systeem is aangestuurd.

### 4. Gedropte bestanden

Beide bestanden zijn door `cmd.exe` (PID 492) weggeschreven op het
**admin-share `C$` van VICTIM-6**, pad `C:\WINDOWS\Help\`:

| Tijd | Bestand | Inhoud/type | Betekenis |
| --- | --- | --- | --- |
| 00:52:15Z | `Recon.bat` | ASCII-tekst: `dir /s C:\ >FileList.txt` | reconnaissance-script: inventariseert de volledige C:-schijf van VICTIM-6 |
| 00:52:25Z | `7za.exe` | PE-executable (MZ-header, 587.776 bytes) | 7-Zip command-line tool — vermoedelijk om data op VICTIM-6 te comprimeren vóór exfiltratie |

### 5. Persistence

Niet gevonden — en dat is zelf ook een bevinding. Ik heb gericht gezocht naar
een nieuwe Run-key, service, geplande taak of Winlogon-koppeling die bij
`Recon.bat`/`7za.exe` of bij het Explorer/`cmd.exe`-stel hoort, maar van de
zo'n 700 autostart-items op dit systeem is op één na alles een doodgewone
Windows- of VMware Tools-regel. Ook de modules die `Explorer.EXE` inlaadt
zijn allemaal standaard Windows-DLL's (plus één legitiem Mandiant-bestand) —
geen rare, ingeladen code te zien.

Dat past bij het beeld dat de aanvaller hier nog in de **verkennende fase**
zit: eerst rondkijken en gereedschap klaarzetten op VICTIM-6, en zich nog
niet structureel ingraven. Hoe de aanvaller precies bij VICTIM-5 is
binnengekomen (en of daar wél iets permanents staat) blijft met alleen deze
puntopname onduidelijk.

### 6. Lateral movement

Ja. In gewone taal: de aanvaller springt vanaf VICTIM-5 door naar de
buurman, VICTIM-6. Zo ziet dat eruit op een rijtje:

1. `00:47:4x` — `Explorer.EXE` (PID 680) praat met `attacker-2`
   (`192.168.7.137`), verstopt achter het domeintje `msoutlookg.com` (zie
   vraag 1).
2. `00:50:24Z` — `cmd.exe` (PID 492, kind van diezelfde Explorer.EXE) start
   op, onder het account `Alice_Admin`.
3. `00:52:15Z` — eerst een ping naar VICTIM-6 (`192.168.7.136`) om te kijken
   of die aanstaat, meteen gevolgd door een verbinding op poort 139 (SMB).
4. `00:52:15Z`–`00:52:25Z` — `cmd.exe` zet via die SMB-verbinding twee
   bestanden rechtstreeks op de C-schijf van VICTIM-6 (zie vraag 4).

Kortom: eerst checken of de buurman thuis is, dan via de voordeur (het
standaard Windows-bestandsdelen-protocol, met een admin-wachtwoord dat
blijkbaar al bekend/bruikbaar was) naar binnen en spullen neerzetten. Precies
zo werkt ook bekend gereedschap als PsExec.

### 7. Data-exfiltratie

Geen rechtstreeks bewijs van data die ván VICTIM-5 áf is gegaan — het
IE-downloadgeschiedenis- en browse-overzicht bevat alleen standaard
Windows/Microsoft Update-verkeer. Wel is er een sterke **voorbereiding op
exfiltratie vanaf VICTIM-6**: `Recon.bat` inventariseert de hele schijf naar
`FileList.txt`, en `7za.exe` (archiveringstool) is daar meteen naast gezet.
Het logische vervolg — `FileList.txt`/geselecteerde bestanden inpakken met
`7za.exe` en wegsturen — valt buiten het opgenomen tijdvenster van deze
triage-collectie.

### 8. SOC-advies

- **Isoleer VICTIM-5 en VICTIM-6 direct** van het netwerk; VICTIM-5 is het
  bronsysteem van de aanval, VICTIM-6 het (voorgenomen) volgende doelwit.
- **Reset de credentials van `Alice_Admin`** (en elk ander account dat met
  dit systeem geassocieerd is) — de aanvaller handelt onder die
  gebruikerscontext.
- **Verwijder `C:\WINDOWS\Help\Recon.bat` en `7za.exe`** op VICTIM-6 en
  controleer of `FileList.txt` al is aangemaakt/gevuld.
- **Blokkeer SMB (139/445) tussen workstations onderling** (alleen
  toestaan richting file-/domain-servers) om dit soort lateral movement
  structureel te bemoeilijken.
- Zoek in bredere EDR/netwerk-logging naar **meer DNS-lookups voor
  `msoutlookg.com`** en naar **meer `C$`-schrijfacties met dezelfde
  `7za.exe`-MD5 (`42badc1d2f03a8b1e4875740d3d49336`)** om te bepalen hoeveel
  andere hosts al geraakt zijn.
- Zoek uit **hoe `Alice_Admin` precies aan haar sessie/wachtwoord is gekomen**
  (phishing, hergebruikt wachtwoord, al eerder gestolen hash?) — dat is het
  stuk dat met alleen deze puntopname nog open staat.

### 9. Overige bevindingen

- **De DNS-cache verraadt het hele plaatje in drie regels**: `msoutlookg.com`
  → CNAME `attacker-2`, en de reverse lookup van `192.168.7.137` komt ook
  uit op `attacker-2`. Je hoeft dus niet eens iets te "kraken" — de namen
  staan er gewoon letterlijk bij in dit oefenbestand.
- **`7za.exe`-MD5**: `42badc1d2f03a8b1e4875740d3d49336` — bruikbaar als
  concrete IOC om elders in het netwerk op te zoeken.
- **`Recon.bat`-MD5**: `686df23e6e77267926420ca7ce0cfbfb`.
- Dit is duidelijk een opzettelijk aangelegde **oefen-/labomgeving**: VMware
  Tools, hostnamen `victim-5`/`victim-6`/`attacker-2`, domein `RESEARCH`, en
  tijdstempels uit **2013** op een Windows XP-systeem met Redline-installers
  tot en met 2020. Oud spul dus, en zoals in [Tooling](#tooling) al staat:
  Redline zelf werkte ook met de nieuwste installer en via Wine niet altijd
  lekker mee. Maar de truc die hier gebruikt wordt — een host aftasten en
  dan via het standaard Windows-bestanden-delen bij de buren inbreken — is
  nog steeds springlevend, ook op recentere Windows-versies.
- Redline's eigen "Issues"-paneel liet geen automatische waarschuwingen zien
  (er was geen IOC-definitiebestand geladen bij deze collectie) — alle
  bovenstaande bevindingen komen uit zelf doorzochte timeline-/DNS-data, niet
  uit een kant-en-klare rode vlag van Redline.
