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

## Open in Xcode 27

```sh
open AetherTable.xcodeproj
```

The project was generated and validated with Xcode 27. Set an iOS 26 simulator destination, then run the `AetherTable` scheme.

## First playable slice

1. Create one local solo campaign from the `d20-fantasy` prototype pack.
2. Load a persisted campaign state and show a recap.
3. Enter intent; AI produces a structured proposal.
4. Rules Engine validates it, Dice Engine rolls it, then the event log updates.
5. Add a second device through the multiplayer event feed—without changing game rules.

## Status

First vertical slice built: create a local solo campaign, submit an action, resolve a pack-defined seeded roll, append it to the campaign event log, and persist the campaign as JSON in Application Support. On an Apple Intelligence-ready device, Foundation Models supplies a guided, structured intent proposal; on other devices, the player’s direct intent remains usable.
