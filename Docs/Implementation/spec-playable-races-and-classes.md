---
title: 'Full first-edition class and ancestry expansion'
type: 'feature'
created: '2026-09-05'
status: 'in-review'
baseline_commit: 'd00bace'
context:
  - '/Users/chris/Documents/Codex/AetherTable/Docs/Architecture.md'
  - '/Users/chris/Documents/Codex/AetherTable/Docs/RulesPacks/Permitted-D20-Sources.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** AetherTable currently offers only Fighter, Rogue, Wizard, and Cleric alongside Human, Dwarf, Halfling, and Orc. Chris wants the remaining core level-one fantasy archetypes plus Tiefling, Dragonborn, Elf, and Gnome. Adding selectable labels without rules-backed creation, spellcasting, and resolution would repeat the existing “scaffold instead of game” failure.

**Approach:** Ship a rules-complete expansion of Barbarian, Bard, Druid, Monk, Paladin, Ranger, Sorcerer, and Warlock alongside Tiefling, Dragonborn, Elf, and Gnome. Reuse existing mechanics where valid and add explicit persistent state/action resolvers where a class’s defining level-one feature needs one; never disguise a manual-adjudication note as implementation.

## Boundaries & Constraints

**Always:** Keep player choice authoritative, mechanics deterministic and auditable, campaigns backward compatible, and all delivered rules within the bundled SRD 5.2.1 subset. Every selectable class spell and feature must change canonical state or have a bounded engine receipt. Character creation, presets, HUD, rest recovery, memory context, and physical d20 flow must all recognize the new choices. Each class’s resource and feature state must survive save/reopen and long rest according to its implemented limits.

**Ask First:** Adding any spell, transformation, summon, or feature whose full deterministic resolver is not implemented in this release; adding copyrighted non-SRD content; changing the user’s requested full-scope ordering.

**Never:** Present unimplemented ancestry/class abilities as functioning mechanics; silently change an existing campaign’s class/species; broaden into multiplayer, other genres, tactical maps, or a new combat subsystem. Do not collapse a class into a generic spellcaster or fighter merely to meet a picker count.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Class creation | Legal new-class draft | Correct hit points, saves, skills, equipment, spells, and defining feature state | Invalid selections explain the specific missing/illegal choice. |
| Feature turn | Class uses its defining level-one action/resource | Deterministic receipt, modified state, and no reroll on retry | Unsupported use leaves state/draft unchanged. |
| Ancestry choice | Elf, Gnome, Tiefling, or Dragonborn selected | Saved identity, languages/context, and only implemented trait effects persist | No invented advantage, damage, resistance, or utility is granted. |
| Old campaign | Existing four-class save reopened | Existing hero remains unchanged and readable | Migration-free decoding preserves prior data. |

</frozen-after-approval>

## Code Map

- `RulesPacks/Sources/OpenWorldState.swift` -- class/ancestry metadata, hero resources, presets, equipment/proficiency.
- `RulesPacks/Sources/CharacterCreation.swift` -- legal creation choices, derived statistics, spell selection, serialization.
- `RulesPacks/Sources/CreationSpellCatalog.swift` -- supported, resolvable class spell lists.
- `RulesPacks/Sources/OpenWorldEngine.swift` -- deterministic class resources, spell DC/attack resolution, long-rest recovery.
- `AetherTableApp/Sources/CharacterCreationView.swift` -- creation controls and class/species explanations.
- `AetherTableApp/Sources/AdventureView.swift` -- resource HUD independent of hard-coded caster names.
- `AetherTableTests/Sources/*Creation*Tests.swift` and `SpellCreationTests.swift` -- creation, resource, spell, and regression coverage.

## Tasks & Acceptance

**Execution:**

- [ ] `RulesPacks/Sources/OpenWorldState.swift` and `CharacterCreation.swift` -- introduce metadata-driven rules for all six requested classes and four ancestries, including legal selections, saves, skills, HP, equipment, spells, resources, presets, and backward-compatible encoding.
- [ ] `RulesPacks/Sources/CreationSpellCatalog.swift`, `CreationFeatureRules.swift`, and `OpenWorldEngine.swift` -- expose only resolved spells; add persisted deterministic state/actions for Rage, Martial Arts, Wild Shape, Hunter’s Mark/Favored Enemy, Lay on Hands/Divine Smite, Pact Magic/Invocations, Bardic Inspiration, and Innate Sorcery, plus recovery/receipts.
- [ ] `AetherTableApp/Sources/CharacterCreationView.swift`, `AdventureView.swift`, and character/journal surfaces -- make every option understandable and surface active resources, forms, slots, and ancestry effects without class-name exceptions.
- [ ] `AetherTableTests/Sources` -- add table-driven creation/round-trip coverage for all classes/ancestries, feature lifecycle tests, spell/action resolver tests, ancestry scope guards, and d20 UI-path regression tests.

**Acceptance Criteria:**

- Given any newly added class, when it uses a defining level-one action, casts a supported spell, or rests, then its legal modifier, resource use, recovery, and outcome are visible in the auditable engine record.
- Given Elf, Gnome, Tiefling, or Dragonborn creation, when the campaign is saved and reopened, then identity/context and only explicit implemented benefits survive unchanged.
- Given any supported caster, when viewing an adventure, then spell slots and relevant resources are shown without a Wizard/Cleric-only condition.
- Given an existing campaign, when it opens after the expansion, then it retains its original class, species, and mechanical state.

## Design Notes

The requested scope is intentionally large. The underlying implementation may land in dependency-ordered commits, but all twelve classes and four new ancestries remain one acceptance boundary: no class or ancestry is called delivered until its creation, engine, persistence, UI, and regression coverage all pass.

## Verification

**Commands:**

- `DEVELOPER_DIR=/Users/chris/Downloads/Xcode-beta.app/Contents/Developer xcodebuild -quiet -project AetherTable.xcodeproj -scheme AetherTable -destination 'platform=iOS Simulator,name=iPhone 17' test` -- expected: all tests pass.
- `DEVELOPER_DIR=/Users/chris/Downloads/Xcode-beta.app/Contents/Developer xcodebuild -quiet -project AetherTable.xcodeproj -scheme AetherTable -destination 'id=00008140-00120C3E1A07801C' -derivedDataPath work/PhoneBuild build` -- expected: signed physical-device build succeeds.
