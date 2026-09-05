# SRD 5.2.1 Rules Package

## Status

**Reference package established; not yet playable.**

This is AetherTable’s separate package boundary for the official System Reference Document v5.2.1. It is not mixed into the original `d20-fantasy` pack, and it does not make a claim that the whole Dungeons & Dragons game, its settings, books, trademarks, art, or marketplace material are bundled in AetherTable.

## Source and license

- Official source: [System Reference Document v5.2.1](https://www.dndbeyond.com/srd)
- License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/legalcode)
- Source version: SRD 5.2.1

### Required attribution

> This work includes material taken from the System Reference Document 5.2.1 by Wizards of the Coast LLC and available at https://www.dndbeyond.com/srd. The System Reference Document 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode.

This attribution must be presented in the package’s About/License view and any distributed rules content. It is carried in code with the package descriptor so releases cannot forget it.

## Package boundary

```text
RulesPacks/SRD521RulesPack.swift
  -> provenance and attribution metadata
  -> rule adapter (to be built)
  -> official-SRD-only data assets (to be added)
  -> deterministic conformance tests (to be added)
```

### Included only after implementation and test

1. Ability checks and proficiency.
2. Advantage/disadvantage.
3. Saving throws.
4. Attack, armor class, damage, and SRD conditions.
5. Character options and resources covered by the selected SRD version.

### Never infer permission for

- Material outside SRD 5.2.1.
- D&D settings, adventures, artwork, trade dress, logos, or marketplace content.
- A statement of endorsement, affiliation, or official D&D app status.

## Product rule

The SRD package becomes selectable only when its mechanics adapter has deterministic conformance coverage. Until then, AetherTable continues to ship the separate owned starter rules packet.
