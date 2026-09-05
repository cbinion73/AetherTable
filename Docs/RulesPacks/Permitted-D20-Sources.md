# Permitted D20 Sources

## Decision

AetherTable ships only the official, English-language D&D System Reference Documents that Wizards released under **Creative Commons Attribution 4.0 International**:

| Source | Rules generation | Status in AetherTable | Bundled |
|---|---:|---|---|
| SRD 5.2.1 | 2024/5.5e | Active implementation source | Yes |
| SRD 5.1 | 2014/5e | Archived compatibility source; separate future adapter | Yes |
| D&D Beyond Basic Rules | 2024 | Official free web reference only | No |
| Paid core books, expansions, settings, adventures, art, and marketplace content | Varies | Not imported | No |

## Why the line matters

The SRD page explicitly licenses SRD content for creators under CC-BY-4.0, including commercial use with attribution. It also says the SRD is not the whole D&D game and identifies material excluded for brand and IP reasons.

The D&D Beyond Basic Rules are free to access, but their page does not provide an open redistribution license. AetherTable may link a player to that official page; it must not scrape, mirror, or package its text, tables, artwork, or data.

## Version integrity

SRD 5.1 and SRD 5.2.1 are different rules generations. Campaigns, characters, event logs, and multiplayer sessions must carry one explicit rules-pack version. Mechanics and data from the two versions cannot be silently mixed.

## Verification record

- SRD 5.2.1: 364 pages; SHA-256 `8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87`
- SRD 5.1: 403 pages; SHA-256 `2504d2a0abb0a4d491a939be4f17910a2dde0312570ab8d208080225ccf0a1f0`

Each package carries the attribution wording required by its own source document. The app must show it wherever that source’s content is distributed.
