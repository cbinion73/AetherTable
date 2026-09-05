# AetherTable

A native, solo, text-based fantasy RPG. Apple Intelligence is the Dungeon Master: it creates scenes, plays NPCs, follows detours and responds to the player's own words. A deterministic engine owns dice, combat and character resources. The campaign remembers the conversation and world developments between sessions.

**No suggested actions. No choice menus in play.** Emberwake is a starting place, not a prescribed route or finite quest tree. AetherTable is a working name and can be renamed independently of its module contracts.

## First edition — in development

- Seven-stage character creation for Fighter, Rogue, Wizard and Cleric: species, background, six ability scores (27-point buy or standard array), training, magic, equipment, written backstory and review.
- Creation backstory is saved as immutable origin history. New relationships can be earned during play; unsupported retroactive personal-history claims are checked separately.
- Free-text exploration, dialogue, creative problem-solving, side quests and combat.
- Native campaign library, adventure transcript, character/equipment sheet, journal and searchable offline rules.
- Seeded d20 checks, advantage/disadvantage, attacks/criticals, class resources, selected spells and short/long rests.
- Atomic local saves, full conversation archive, structured world memory and bounded context retrieval.
- Preserved drafts, cancellation and retry without rerolling an already adjudicated intent.

This is currently a **level-one SRD 5.2.1 rules subset**, not a completed first edition or every rule in D&D. Full advancement, additional classes/spells, complete species/feat/mastery mechanics, tactical movement, opportunity attacks and death saves remain incomplete. The creator discloses partial feature coverage; selecting a feature does not prove its complete mechanical implementation. Multiplayer and other genres are out of scope. Original setting content is separate from the attributed Creative Commons SRD; no proprietary D&D settings or other franchise assets are included.

The model is generative, not infallible. Agency/format checks reject invalid responses; the engine record remains visible under each adjudicated turn. Storage keeps the full history, while each model request receives a bounded, retrieved portion—not unlimited context.

## Run

Open `AetherTable.xcodeproj` and run the `AetherTable` scheme on an Apple Intelligence-capable iPhone with iOS 27 or later. Enable Apple Intelligence and finish its model download. A simulator can exercise the interface and automated tests, but does not prove live model availability.

The app uses Apple's on-device Foundation Models. There is no API key, cloud-model fallback or server account. If the model is unavailable, the app explains the problem and preserves the saved campaign and draft.

```sh
xcodegen generate
xcodebuild -project AetherTable.xcodeproj -scheme AetherTableTests -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

Use an installed simulator name and Xcode 27 or newer. Set `DEVELOPER_DIR` when that Xcode is not the active selection. Physical-device builds use automatic development signing.

The same engine and actual model can be exercised on an Apple Intelligence-enabled Mac:

```sh
swift run GMPlaytest --state work/playtest.json 'I ask the innkeeper about the missing bell.'
```

Reuse the state path for subsequent turns. Errors do not overwrite the last successful save. Rejected-prose diagnostics are opt-in with `AETHERTABLE_GM_DIAGNOSTICS=1` in debug builds, not normal app logging.

## Modules

| Module | Responsibility |
|---|---|
| App | SwiftUI library, creation, conversation, character, journal and rules |
| AIGM | Intent interpretation, storyteller, memory extraction and validation |
| RulesPacks | Versioned adventure state, classes, open-world mechanics, licensed reference |
| RulesEngine / DiceEngine | Shared rules contracts and reproducible audited rolls |
| Core | Campaign, event and world contracts |
| Persistence | Atomic local JSON storage and discovery |
| Multiplayer | Dormant interface only; not part of this edition |

`project.yml` is the XcodeGen source of truth. The Swift package supports Mac GM playtesting; iOS tests run through Xcode. Earlier fixed-scene implementations remain as legacy migration/test fixtures, not active gameplay.

See [architecture](Docs/Architecture.md), [player experience](Docs/PlayerExperience.md), [current contract](Docs/Implementation/spec-open-world-first-edition.md), and [SRD attribution](Docs/RulesPacks/SRD-5.2.1.md). Repository: `/Users/chris/Documents/Codex/AetherTable`.
