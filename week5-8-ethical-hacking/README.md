# Week 5-8: Ethical Hacking / Attack Plan

Aanvalsplan tegen de case Power2Music. In tweetallen, inleveren week 8.
Hack value, reconnaissance, enumeration, hacking (plus testplan en resultaten)
en clearing tracks, elk onderbouwd en getest op de virtuele Power2Music-infra.

Dit is nog een planskelet op basis van de case study; de kolom "resultaat" wordt
pas ingevuld zodra er daadwerkelijk tegen de virtuele infrastructuur getest is
(zie [`TODO.md`](TODO.md)).

## Waarom Power2Music een kwetsbaar doelwit is

Uit de case (hoofdstuk 6 en bijlage 2): de infrastructuur draait grotendeels op
end-of-life software die niet meer ondersteund wordt:

| Component | Versie | Risico |
| --- | --- | --- |
| Domain controllers | Windows Server 2012 R2 | EOL |
| Firewall | Microsoft Forefront TMG 2010 SP2 | product afgeschreven door Microsoft in 2012 |
| Intranet/DMS | IBM WebSphere op Server 2012 R2 | vaak verouderde Java-stack |
| Mail | Exchange Server 2013 + OWA | bekende OWA-CVE's, extern bereikbaar voor werknemers "on the road" |
| VDI-portal | VMware Horizon View 6.2.3 | bereikbaar vanaf branches/thuis — externe ingang |
| Hypervisors | 10x VMware ESXi 6.0 | EOL, bekende ESXi-CVE's |
| ERP/database | SAP ERP 6.0 op Windows Server 2008 R2 + SQL Server 2008 R2 SP3 | zeer oud, 2008 R2 is EOL sinds 2020 |
| MP3-server | Ubuntu Server 12.04 LTS, Apache, Samba, Icecast 2.3.x | EOL sinds 2017, geen patches meer |
| Werkplekken | Windows 10 Pro + IE11 | IE11 niet meer onderhouden |
| DJ-laptops | macOS + Windows 8 Enterprise, lokale MySQL/SQL Front | DJ's werken zelfstandig op events, buiten direct IT-toezicht |

## Hack value

Doel: toegang tot **SAP ERP 6.0 / SQL Server (financiële en klantdata)** en/of
de **VDI-broker (Horizon View)**, omdat:
- financiële data (FINANCE2Music) en klantdata (Customer2Music/CRM) het meest
  schadelijk zijn bij diefstal of versleuteling (privacy, betaalgegevens, continuïteit);
- de Horizon View-broker expliciet bedoeld is als externe toegangspoort voor
  reizende medewerkers en branches — een geslaagde aanval hier geeft lateral
  movement naar de hele VDI-omgeving (en van daaruit naar ESXi/SAP);
- Power2Music zelf aangeeft dat de systemen "mogelijk niet beveiligbaar zijn
  tot een acceptabel niveau" (hoofdstuk 6.1) — het bedrijf verwacht zelf al
  kwetsbaarheden.

## Reconnaissance

| # | Techniek | Doel binnen de case |
| --- | --- | --- |
| 1 | OSINT / Google hacking (dorks, `site:`, `filetype:`, exploit-db GHDB) | publieke info en evt. per ongeluk geïndexeerde bestanden over Power2Music vinden |
| 2 | WHOIS + DNS-enumeratie | domeinnamen, mailservers, IP-ranges van Power2Music achterhalen |
| 3 | Website footprinting (HTML source, cookies, HTTrack-mirror) | gebruikte software/CMS/scripting-platform van de publieke site(s) |
| 4 | Social engineering via LinkedIn (org-structuur, functies uit hoofdstuk 2.8/5) | namen en functies van IT-beheerders (CIO, netwerkbeheerder, SAP-beheerder) herleiden voor phishing-doelwitten |
| 5 | Traceroute / netwerkpad-analyse | pad naar de Rommeldam-serverruimte in kaart brengen, mogelijke MITM-posities |

## Enumeration

| # | Techniek | Doel binnen de case |
| --- | --- | --- |
| 1 | NetBIOS-enumeratie (`nbtstat`, Hyena) | domeincomputers en shares op de Windows Server 2012 R2-AD vinden |
| 2 | SMTP-enumeratie (VRFY/EXPN via telnet op Exchange 2013) | geldige gebruikersaccounts op de mailserver achterhalen |
| 3 | DNS zone transfer-poging | interne hostnamen/IP's van de Rommeldam-infra |
| 4 | SNMP-enumeratie (default community strings op Cisco Catalyst 2960-switches/router) | netwerktopologie en apparaatinformatie |

## Hacking

| # | Techniek | Doel binnen de case | Testplan | Resultaat |
| --- | --- | --- | --- | --- |
| 1 | Exploiteren bekende CVE's op Forefront TMG 2010 / verouderde firewall-regels | initiële toegang tot het netwerk | _nog te testen op lab_ | _TODO_ |
| 2 | OWA/Exchange 2013-aanval (bekende CVE's, password spraying) | mailbox-toegang, mogelijk credential-herbruik richting AD | _nog te testen op lab_ | _TODO_ |
| 3 | Aanval op VMware Horizon View 6.2.3-broker (bekende CVE's) | toegang tot VDI-omgeving, lateral movement naar ESXi 6.0 | _nog te testen op lab_ | _TODO_ |
| 4 | Credential-diefstal op Ubuntu 12.04 MP3-server (verouderde Samba/Apache-CVE's) | pivot-punt + bewijs dat ook "kleinere" systemen een risico zijn | _nog te testen op lab_ | _TODO_ |

## Clearing tracks

| # | Techniek | Toepassing binnen de case |
| --- | --- | --- |
| 1 | Logbestanden wissen/aanpassen op de gecompromitteerde Windows/Ubuntu-servers | sporen van toegang verwijderen |
| 2 | Timestamps aanpassen (anti-forensics) | ontdekking door Redline/forensisch onderzoek bemoeilijken |
| 3 | Acties tijdens kantooruren uitvoeren (08:00-18:00, zoals in hoofdstuk 9.3 omschreven supportvenster) | minder opvallen tussen normaal verkeer |
| 4 | Bestanden/tools versleutelen op het gecompromitteerde systeem | detectie door signature-based tools vermijden |

## Logboek

_Hier komen screenshots/bevindingen van de daadwerkelijke tests op de virtuele
Power2Music-infrastructuur, zodra die beschikbaar is._
