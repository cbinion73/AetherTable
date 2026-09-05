---
title: Real character creation and fixed origin canon
status: in-progress
created: 2026-09-05
---

# Real character creation and fixed origin canon

Chris rejected the preset-only quickstart as insufficient. The first edition must have a genuine character-creation workflow; a menu of preset classes is not completion.

## Required behavior

- Name, class, species, background, appearance and alignment are player choices.
- All six abilities are visible and editable through SRD 5.2.1's 27-point buy or assigned standard array. Apply eligible background increases afterward; validate costs and derive modifiers, HP, AC, skills and casting statistics.
- Choose class/background/species training, languages, feats, mastery and relevant class options. Selected features must affect play; recording inert feature names does not satisfy implementation.
- Wizard creation includes three cantrips, six book spells and four prepared spells. Cleric creation includes three cantrips (four for Thaumaturge), four prepared spells and Divine Order. Magic Initiate has separate casting ability and free-cast resource.
- Choose equipment or gold with real consequences for possession, AC and attacks. Do not silently remove selected supported spells or weapons.
- The player writes a backstory during creation, up to 4,000 characters. Store it as immutable creation data, separate from mutable world memories. Existing longer legacy origins are not truncated on disk.
- The origin can ground relationships, reactions and appropriate situational advantages. It cannot bypass class mechanics or invent ability scores. Claims of privileged family, childhood contacts, education or training introduced later require support in that origin or genuine events earned during play. Explicit in-world lies remain claims, not canonical history.
- Character review precedes saving; invalid allocations cannot create a campaign. The character sheet exposes the resulting choices and locked history.

## Evidence required

Builder tests for legal/illegal scores and choices; deterministic effects for selected features; save/reopen tests for creation and origin; adversarial origin-claim tests and actual model probes; native UI interaction through all stages; signed device installation. Preserve the existing playtest campaigns.

## Completion boundary

The overall game goal remains active. The new creator and its mandatory mechanics must be integrated and verified before declaring this requirement complete. Partial rules coverage must remain explicit; neither green builder tests nor a polished form proves all selected features work in play.

## Verification log — September 5

- `work/creation-verified-tests.xcresult`: 105 tests passed (108 parameter executions), zero failures, skips or runtime warnings. Includes creation save/reopen and invalid-allocation rejection.
- Native simulator interaction traversed all seven stages. Point-buy Strength 15→14 refunded two points; Intelligence 8→10 spent both. Review displayed final STR16/DEX14/CON14/INT10/WIS10/CHA12, HP12 and AC17. Created `Creation QA` with explicit noble-parent/temple backstory; existing Mira Test and Arden campaigns remained in the library.
- Independent review found class changes reset unrelated choices and background changes reset still-valid choices. Fix in progress. Local save-error display added.
- Actual Apple model rejected a supported illusionist-childhood claim. Origin gate requires further tuning and live re-verification; deterministic provenance tests alone do not prove the player experience.
- Class/background preservation fixes and ritual casting are integrated. `work/creation-ritual-integration-tests.xcresult` passed 119 tests (122 parameter executions), with no failures, skips or runtime warnings.
- Origin-gate experiments also exposed a false acceptance using an unrelated genuine quote. A two-stage comparison and narrow absent-relationship/title veto are now implemented, but the final live supported/unsupported pair has not been reverified. Do not treat origin semantic enforcement as solved.
