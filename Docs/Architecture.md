# First-edition architecture

## Storyteller and engine

The model is the Dungeon Master, not a caption generator attached to a fixed adventure. It interprets free-form intent, creates the world and NPCs, and follows player-led exploration and side quests. It never supplies dice totals or directly writes storage.

```text
Player words → model proposes mechanics → engine validates and resolves
             → model tells the next moment → model extracts memory
             → validate candidate → atomic save → publish UI
```

The model proposes fictional difficulty, targets and whether a hostile can respond. The engine owns rolls, modifiers, slots, healing, damage, attacks, rest recovery and existing actor statistics. Only validated and saved turns become committed history. Dice receipts remain available.

`DungeonMaster` is injectable. `AppleDungeonMaster` runs real on-device Foundation Models; tests use explicitly scripted implementations. There is no canned narrator or cloud fallback. A fresh bounded session per stage avoids unbounded session context.

## State and memory

`OpenWorldAdventure` is the authoritative snapshot inside `CampaignState.world.packState["open-world.v1"]`. It stores class resources, stable actors/statistics, equipment, every transcript message and structured world memory. Narrative memory cannot overwrite mechanical fields. Inventory developments reconcile with possession and usable supported weapons.

Current entity memories have stable IDs. Changes retain prior versions as inactive history. The full transcript stays on disk; retrieval ranks relevant memories/older messages and reserves recent conversation within 6,500 characters. This is durable memory with bounded retrieval, not perfect model recall.

Outer events record compact mechanical audits, not full transcript copies per turn. Legacy campaigns import player resources, opponents, notes and world facts. Malformed snapshots are reported without deleting files.

## Persistence and concurrency

The store writes campaign JSON atomically in Application Support. The view model publishes after successful storage. An operation token ignores late model responses after cancellation. Saves cannot be cancelled once started; creation, notes and turns share the mutation lock. Failed generation/save retains the draft and cached adjudication bound to the exact base campaign, preventing rerolls or overwriting intervening notes.

## Boundaries

App depends on AIGM, RulesPacks, Persistence and Core. AIGM depends on RulesPacks/Core but cannot access storage. RulesPacks uses RulesEngine/DiceEngine contracts and Core. Persistence depends only on Core; embedded adventure validation occurs at the app boundary.

The active game is solo 5E-compatible fantasy. Dormant multi-system descriptors and Multiplayer contracts remain extension points, not delivered features.

## Rules and IP

Selected level-one procedures use separately attributed SRD 5.2.1 material. The full reference is offline, but reference availability does not imply every procedure is automated. The Rules screen states the subset. Emberwake's starting premise is original; proprietary franchise content is excluded.

## Validation limits

Format, agency, ID and mechanical guards are deterministic. They cannot prove every generated sentence is semantically consistent or artistically strong. Live model playtesting complements unit tests; mocked tests do not prove a captivating GM. Rejected generation leaves the prior campaign unchanged. Release evidence distinguishes builds/tests, actual model runs and installation.
