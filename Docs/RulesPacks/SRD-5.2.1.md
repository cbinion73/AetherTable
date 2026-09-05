# SRD 5.2.1 Rules Package

## Status

**Official source is bundled. The active solo game uses a tested, partial SRD 5.2.1 adapter; full first-edition rules coverage is still in development.**

This is AetherTable’s separate package boundary for the official System Reference Document v5.2.1. It is not mixed into the original `d20-fantasy` pack, and it does not make a claim that the whole Dungeons & Dragons game, its settings, books, trademarks, art, or marketplace material are bundled in AetherTable.

## Source and license

- Official source: [System Reference Document v5.2.1](https://www.dndbeyond.com/srd)
- License: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/legalcode)
- Source version: SRD 5.2.1
- Bundled source: `RulesPacks/Resources/SRD521/SRD_CC_v5.2.1.pdf` (364 pages; SHA-256 `8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87`)

### Required attribution

> This work includes material from the System Reference Document 5.2.1 ("SRD 5.2.1") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode.

This attribution must be presented in the package’s About/License view and any distributed rules content. It is carried in code with the package descriptor so releases cannot forget it.

The legally distributable 2014-era corpus is archived separately as SRD 5.1. It must not be mixed into a 5.2.1 campaign; see [Permitted D20 Sources](Permitted-D20-Sources.md).

## Package boundary

```text
RulesPacks/SRD521RulesPack.swift
  -> provenance and attribution metadata
RulesPacks/SRD521CoreMechanics.swift
  -> deterministic ability checks, saves, attacks, advantage/disadvantage,
     ability modifiers, and character-level proficiency bonus
RulesPacks/Resources/SRD521/SRD_CC_v5.2.1.pdf
  -> verbatim official source document, checksum-pinned
AetherTableTests/Sources
  -> deterministic conformance tests
```

### Current implementation boundary

The open-world adapter includes checks, attacks, selected damage/spell/resource handling, and a level-one character builder with point-buy and standard-array validation. Character creation covers four classes and selected species/backgrounds. Some selected feats, species traits, mastery properties and tactical procedures still require implementation. The builder's coverage notes must disclose these gaps rather than imply full conformance.

### Never infer permission for

- Material outside SRD 5.2.1.
- D&D settings, adventures, artwork, trade dress, logos, or marketplace content.
- A statement of endorsement, affiliation, or official D&D app status.

## Product rule

The active app uses `OpenWorldAdventure` and `OpenWorldEngine` with the SRD package identifier. Original setting material remains separate. Earlier fixed-scene starter engines remain migration/test fixtures, not the current player experience. A passing test suite proves the covered cases, not implementation of the whole SRD.
