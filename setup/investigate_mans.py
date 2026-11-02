#!/usr/bin/env python3
"""Doorzoekt een Redline .mans-bestand zonder Redline zelf nodig te hebben.

Een .mans ("Mandiant Analysis Session") is gewoon een zip-bestand met
XML-auditdata erin (zie manifest.json). Redline is alleen de GUI eromheen.
Dit scriptje unzipt het bestand, en doorzoekt de belangrijkste audits met
simpele regex-zoekacties op verdachte patronen:

- netwerkverbindingen (en: wordt er eerst gepingd en dan verbonden op een
  SMB-poort (139/445) naar hetzelfde IP? klassiek voorbeeld van 'eerst checken
  of de buurman thuis is, dan de voordeur proberen')
- bestanden die weggeschreven worden over een remote admin-share
  (LanmanRedirector-pad = iemand schrijft iets op een ANDERE machine)
- DNS-cache: CNAME/PTR-ketens, zodat een nep-domeinnaam die naar een andere
  host wijst meteen opvalt
- user-accounts met Administrator-rechten en hun laatste login

Gebruik:
    ./investigate_mans.py                              # pakt het .mans-bestand uit de assignments-map
    ./investigate_mans.py pad/naar/Investigation.mans   # of een specifiek bestand
"""
from __future__ import annotations

import re
import sys
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANS = REPO_ROOT / "Operational Security - Assignments" / "Redline Investigation.mans"


def load_payload(zf: zipfile.ZipFile, manifest: str, generator: str, content_type: str = "application/xml") -> str | None:
    """Vindt via manifest.json (regex, geen json-parser nodig voor deze opzet) de payload van een generator."""
    # Elke generator-blok in het manifest, zoek het payload-id waarvan het type matcht.
    blocks = re.findall(
        rf'"generator"\s*:\s*"{re.escape(generator)}".*?"audits"|\{{[^{{}}]*"generator"\s*:\s*"{re.escape(generator)}".*?\}}\]',
        manifest, re.S,
    )
    # manifest.json heeft geneste structuur; simpeler: zoek het generator-blok met een brede match
    m = re.search(rf'"generator"\s*:\s*"{re.escape(generator)}"(.*?)"generator"\s*:', manifest, re.S)
    block = m.group(1) if m else manifest[manifest.find(f'"generator": "{generator}"'):]
    payload_m = re.search(rf'"payload"\s*:\s*"([^"]+)"\s*,\s*"type"\s*:\s*"{re.escape(content_type)}"', block)
    if not payload_m:
        return None
    payload_id = payload_m.group(1)
    try:
        return zf.read(payload_id).decode("utf-8", errors="ignore")
    except KeyError:
        return None


def parse_event_details(block: str) -> dict:
    return dict(re.findall(r"<name>([^<]*)</name>\s*<value>(.*?)</value>", block, re.S))


def section(title: str) -> None:
    print(f"\n{'=' * 70}\n{title}\n{'=' * 70}")


def main() -> None:
    mans_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_MANS
    if not mans_path.exists():
        sys.exit(f"Bestand niet gevonden: {mans_path}")

    print(f"Analyseer: {mans_path}")
    with zipfile.ZipFile(mans_path) as zf:
        manifest = zf.read("manifest.json").decode("utf-8", errors="ignore")

        timeline = load_payload(zf, manifest, "stateagentinspector")
        dns_cache = load_payload(zf, manifest, "w32network-dns")
        processes = load_payload(zf, manifest, "w32processes-memory")
        users = load_payload(zf, manifest, "w32useraccounts")

    # --- Admin-gebruikers ---
    if users:
        section("Admin-accounts op dit systeem")
        for item in re.findall(r"<UserItem.*?</UserItem>", users, re.S):
            if "Administrators" in item:
                name = re.search(r"<Username>([^<]*)</Username>", item)
                last = re.search(r"<LastLogin>([^<]*)</LastLogin>", item)
                print(f"  - {name.group(1) if name else '?'}  (laatste login: {last.group(1) if last else '?'})")

    # --- Procesboom (parent/child) ---
    pid_info = {}
    if processes:
        section("Processen (pid -> naam, parent, gebruiker)")
        for item in re.findall(r"<ProcessItem.*?</ProcessItem>", processes, re.S):
            pid = re.search(r"<pid>(\d+)</pid>", item)
            name = re.search(r"<name>([^<]*)</name>", item)
            parent = re.search(r"<parentpid>(\d+)</parentpid>", item)
            user = re.search(r"<Username>([^<]*)</Username>", item)
            if pid:
                pid_info[pid.group(1)] = name.group(1) if name else "?"
                print(f"  {pid.group(1):>6}  {name.group(1) if name else '?':<16} "
                      f"parent={parent.group(1) if parent else '?':<6} user={user.group(1) if user else '?'}")

    # --- Timeline-events: netwerk, dns, file writes ---
    events = []
    if timeline:
        for uid, block in re.findall(r'<eventItem uid="(\d+)">(.*?)</eventItem>', timeline, re.S):
            etype = re.search(r"<eventType>([^<]+)</eventType>", block)
            ts = re.search(r"<timestamp>([^<]+)</timestamp>", block)
            if etype and ts:
                events.append((ts.group(1), etype.group(1), parse_event_details(block)))
        events.sort(key=lambda e: e[0])

    # --- DNS lookups door user-processen (geen systeemupdates/CRL-ruis) ---
    section("DNS-lookups (per proces)")
    dns_lookups = [(ts, d) for ts, et, d in events if et == "dnsLookupEvent"]
    seen = set()
    for ts, d in dns_lookups:
        key = (d.get("process"), d.get("hostname"))
        if key not in seen:
            seen.add(key)
            print(f"  {ts}  {d.get('process','?'):<14} (pid {d.get('pid','?')})  -> {d.get('hostname')}")

    # --- Netwerkverbindingen: groepeer per (proces, remote ip, poort) ---
    section("Netwerkverbindingen (uniek per proces -> IP:poort)")
    net_events = [(ts, d) for ts, et, d in events if et == "ipv4NetworkEvent"]
    seen = set()
    for ts, d in net_events:
        key = (d.get("process"), d.get("pid"), d.get("remoteIP"), d.get("remotePort"))
        if key not in seen:
            seen.add(key)
            print(f"  {ts}  {d.get('process') or '(system)':<14} (pid {d.get('pid','?')})"
                  f"  -> {d.get('remoteIP')}:{d.get('remotePort')} [{d.get('protocol')}]")

    # --- Heuristiek: ping gevolgd door SMB (139/445) naar hetzelfde IP binnen enkele seconden ---
    section("Mogelijke scan/lateral movement (ping + SMB-verbinding naar hetzelfde IP)")
    icmp_targets = {d.get("remoteIP") for ts, d in net_events if d.get("protocol") == "ICMP"}
    smb_hits = [(ts, d) for ts, d in net_events if d.get("remotePort") in ("139", "445")]
    flagged = False
    for ts, d in smb_hits:
        if d.get("remoteIP") in icmp_targets:
            flagged = True
            print(f"  {ts}  {d.get('process') or '(system)'} (pid {d.get('pid')}) -> SMB naar {d.get('remoteIP')} "
                  f"(dit IP werd ook gepingd — ruikt naar verkennen + binnenkomen)")
    if not flagged:
        print("  Niets gevonden.")

    # --- Bestanden geschreven over een remote admin-share ---
    section("Bestanden weggeschreven op EEN ANDERE machine (admin-share / LanmanRedirector)")
    file_events = [(ts, d) for ts, et, d in events if et == "fileWriteEvent"]
    for ts, d in file_events:
        path = d.get("fullPath", "")
        if "LanmanRedirector" in path:
            print(f"  {ts}  {d.get('process')} (pid {d.get('pid')}) schrijft: {path}")
            text = d.get("textAtLowestOffset")
            if text:
                print(f"           inhoud (eerste bytes): {text!r}")
            md5 = d.get("md5")
            if md5:
                print(f"           md5: {md5}")

    # --- DNS-cache: alle CNAME/PTR-records, zodat nep-domeinen die naar een andere host wijzen opvallen ---
    if dns_cache:
        section("DNS-cache: CNAME/PTR-ketens (let op domeinen die naar een onverwachte hostnaam wijzen)")
        for item in re.findall(r"<DnsEntryItem.*?</DnsEntryItem>", dns_cache, re.S):
            rtype = re.search(r"<RecordType>([^<]*)</RecordType>", item)
            host = re.search(r"<Host>([^<]*)</Host>", item)
            if rtype and rtype.group(1) in ("CNAME", "PTR"):
                data = re.search(r"<RecordData>\s*<(?:Host|IPv4Address)>([^<]*)</(?:Host|IPv4Address)>", item, re.S)
                print(f"  {host.group(1) if host else '?'}  ({rtype.group(1)})  -> {data.group(1) if data else '?'}")

    print("\nKlaar. Dit is dezelfde data die Redline's Timeline/DNS Entries/File System-tabs laten zien — "
          "alleen dan zonder een crashende .NET-WinForms-app uit het XP-tijdperk ertussen.")


if __name__ == "__main__":
    main()
