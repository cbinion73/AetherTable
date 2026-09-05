# AetherTable

**AetherTable is one persistent, AI-native tabletop platform—not a collection of game-specific apps.**

It lets a player open a campaign, receive an accurate recap, make a choice, roll verified dice, and leave without losing the world. The AI Game Master narrates, role-plays, and proposes intent. The deterministic game engine adjudicates rules, rolls, and state changes.

## The core idea

One platform kernel supports many **Rules Packs**. A pack is data plus a narrow rules adapter:

```text
Platform kernel: campaigns, characters, world state, journal, dice, sync, AI GM
                 +
Rules Pack: mechanics definitions, actions, schemas, presentation vocabulary
```

The initial packs are intentionally original and generic:

- `d20-fantasy` — a compatibility-shaped fantasy prototype
- `momentum-2d20` — a starship-exploration-style prototype
- `heroic-pool` — a superhero-style prototype

They are **not** implementations of, or content for, Dungeons & Dragons, Star Trek, Marvel, Warcraft, or any other third-party IP. Official rules, settings, artwork, trademarks, and text require their respective licenses or a publisher-approved open license.

## Architecture

| Module | Responsibility |
|---|---|
| `AetherTableApp` | SwiftUI experience and composition root |
| `AetherTableCore` | Stable campaign, world, event, and pack contracts |
| `AIGM` | Apple Foundation Models boundary; proposes narrative and structured intents only |
| `RulesEngine` | Validates player actions and produces deterministic state events |
| `DiceEngine` | Seedable, auditable dice expressions and rolls |
| `Persistence` | Local campaign snapshot/event storage contract |
| `Multiplayer` | Turn/event synchronization contract; transport remains replaceable |
| `RulesPacks` | Data-driven mechanics profiles and pack registry |

More detail: [Docs/Architecture.md](Docs/Architecture.md).

The product decision record and gate-based delivery plan: [Docs/PRD.md](Docs/PRD.md).

The owned starter adventure and its small rules reference: [Docs/ReferenceCampaign.md](Docs/ReferenceCampaign.md).

The official SRD 5.2.1 source is isolated in a separately attributed package. Its deterministic core currently supports ability checks, saving throws, attack rolls, advantage/disadvantage, ability modifiers, and proficiency progression; it is not yet a complete playable SRD campaign system. Scope and license boundary: [Docs/RulesPacks/SRD-5.2.1.md](Docs/RulesPacks/SRD-5.2.1.md).

The repository also preserves the separately licensed SRD 5.1 for a future 2014-compatible adapter. It does not copy free-to-read D&D Beyond Basic Rules or paid D&D content without an explicit redistribution license. Full source policy: [Docs/RulesPacks/Permitted-D20-Sources.md](Docs/RulesPacks/Permitted-D20-Sources.md).

On the phone, rules are structured, source-cited records with deterministic offline search—not a vector database. The engine resolves by stable rule ID; the AI may only use retrieved records to explain an already-grounded ruling.

## Open in Xcode 27

```sh
open AetherTable.xcodeproj
```

The project was generated and validated with Xcode 27. Set an iOS 26 simulator destination, then run the `AetherTable` scheme.

## First playable slice

1. Begin The Lantern Below with the fixed SRD Guardian quickstart character.
2. Resolve the River Shade encounter through the deterministic encounter engine.
3. Make choices in the Flooded Archive and Lantern Vault.
4. Save the resulting campaign state and resume it when reopening the app.

This is an SRD-based adaptation of the reference campaign's three locations. The reference packet's selectable archetypes and four investigative opening approaches are not implemented in the current phone flow. Free-text play and adding a second device remain later work.

## Status

The initial scaffold milestone is complete. The repository was initialized in commit `bea798b` and already contains the eight modules above, a native iOS application, architecture notes, and automated engine tests. Continue this repository at `/Users/chris/Documents/Codex/AetherTable`; AetherTable remains a working name.

The current phone UI opens the original **The Lantern Below** solo adventure, resumes a saved campaign, and presents scene choices, combat, Archive branches, and a Vault ending. Campaign state is saved as JSON in Application Support. Foundation Models supplies outcome narration when available. The AI layer also contains structured intent proposal support; that does not imply that every scene supports unrestricted free-text play.

| User requirement | Current implementation | Still required for the full game |
|---|---|---|
| Native iOS app | SwiftUI app and separate framework targets | Broader device and player testing |
| Apple Intelligence GM | Foundation Models proposals and outcome narration boundary | Full scene generation, NPC dialogue, and grounded ongoing campaign behavior |
| Persistent world | Structured state, event reducer, atomic JSON saves, resume flow | Save migration and interruption/recovery verification |
| Deterministic dice and rules | Audited dice, rules engine, SRD 5.2.1 core mechanics and encounter subset | Complete supported rules coverage and conformance checks |
| Solo and multiplayer | Solo adventure; multiplayer transport protocol only | Actual shared sessions, player authority, synchronization, reconnect/conflict handling, and two-device verification |
| Multiple RPG systems | Versioned pack interface; d20, 2d20, and dice-pool descriptors | Distinct playable systems and genre experiences; descriptors alone do not implement those systems |
| Published rules and IP boundaries | Separately attributed SRD sources and scoped mechanics | Rights and exact edition selection before implementing additional published systems/settings |

Multiplayer and multiple playable systems remain requirements for the full product. Solo-first is an implementation sequence, not removal of those requirements. The scaffold and current adventure are not the completed platform.

## Build and test

Open `AetherTable.xcodeproj` in Xcode 27 and choose an installed iOS simulator. To regenerate the project after changing `project.yml`, run `xcodegen generate` (XcodeGen 2.44 or newer).

```sh
xcodebuild -project AetherTable.xcodeproj -scheme AetherTable -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
xcodebuild -project AetherTable.xcodeproj -scheme AetherTableTests -destination 'platform=iOS Simulator,name=iPhone 17' test CODE_SIGNING_ALLOWED=NO
```

Use a simulator name available on your Mac. If Xcode 27 is not the active developer directory, set `DEVELOPER_DIR` to its `Contents/Developer` directory. Physical-device builds require your own development team and provisioning; simulator builds do not.

GDS workflow configuration lives in `_bmad/gds/config.yaml`. Existing product and architecture documents remain the planning sources; this configuration does not imply that every GDS design or acceptance gate has passed.
