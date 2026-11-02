# Operational Security: portfolio

[![CodeTrunk mirror](https://img.shields.io/badge/mirror-CodeTrunk%20(EU)-2496ED)](https://repos.codetrunk.eu/Stensel8/Operational-Security)

Portfolio voor de module Operational Security (Saxion). Eén map per week.

Ik werk hierbij met AI-assistentie, via IDE-integraties. De opzet, keuzes en het testen zijn van mij, maar een deel van het typewerk en het debuggen doe ik samen met deze tools.

- Anthropic. (2026). *Claude (Sonnet 5)* [Large language model]. [https://claude.ai](https://claude.ai)
- Mistral AI. (2026). *Mistral Vibe (GLM 5.3)* [Large language model]. [https://mistral.ai](https://mistral.ai)

**PDF/ODT-export van deze portfolio.** Bij elke push naar `main` zet een GitHub Actions-workflow ([`.github/workflows/docs.yml`](.github/workflows/docs.yml)) automatisch een PDF en een ODT klaar met alle informatie uit de repo, als assets bij een nieuwe [release](../../releases). Ik heb deze exports dus niet zelf handmatig gemaakt; ze worden automatisch gegenereerd vanuit de README's via [`setup/export-portfolio.sh`](setup/export-portfolio.sh) (pandoc + typst).

De repository staat ook gespiegeld op [CodeTrunk](https://repos.codetrunk.eu/Stensel8/Operational-Security), een Europese Git-host met IPv6-ondersteuning: voor redundantie en omdat ik niet alles alleen op GitHub (VS) wil hebben staan.

- [week1-2-siem/](week1-2-siem/): SIEM met Wazuh + OpenObserve i.p.v. Security Onion + ELK
- [week3-4-incident-response/](week3-4-incident-response/): Digital Forensics met Redline
- [week5-8-ethical-hacking/](week5-8-ethical-hacking/): Aanvalsplan Power2Music (duo)
