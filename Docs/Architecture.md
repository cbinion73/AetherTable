# Architecture decision record: one kernel, many packs

## Non-negotiable boundary

The AI Game Master is not the game engine. It may describe a consequence, select an NPC voice, propose an action classification, and generate a recap. It never mutates campaign state directly, invents a dice result, or decides whether an action is legal.

```text
Player intent
    -> AI GM proposes structured intent (optional)
    -> Rules Engine validates against active Rules Pack
    -> Dice Engine resolves seedable audited rolls
    -> Event log is appended
    -> Persistence saves local truth
    -> Multiplayer distributes the same events
    -> AI GM narrates the already-resolved outcome
```

## Campaign truth

`CampaignState` is a compact materialized view. `CampaignEvent` is the durable audit trail. Each event carries a stable identifier and date. A future sync transport will also need explicit ordering, deduplication, and authority semantics before it can safely merge events without making the AI authoritative.

The first persistence adapter is local and replaceable. CloudKit sharing is the expected Apple-native multiplayer candidate, but it is an implementation choice for the next milestone, not an unearned claim in this scaffold.

## Rules packs

Every pack identifies itself by an owned identifier and version. It supplies a mechanic family, a list of declared actions, and UI/narrative vocabulary. The platform owns identities, campaigns, dice audit records, events, persistence, and sync.

Rules Packs must only contain material we own or are licensed to distribute. A “compatible with” claim is a legal/product decision, not an engineering convenience; do not add publisher marks, setting names, protected stat blocks, or rule text to a pack without rights review.

### Phone-native rules retrieval

Rules packs ship as compact structured records plus an offline deterministic search index. The Rules Engine addresses records by stable identifier and never delegates adjudication to retrieval. Full-text search serves the player and AI GM only when a rule needs to be located or explained; every result includes its rules version, source section, and source page. Semantic/vector retrieval is deferred until campaign-memory evidence shows it improves player questions beyond this local, source-cited path.

## Apple Intelligence

`FoundationModelsGM` is conditionally compiled for Apple platforms that provide Foundation Models. It generates a guided `GMIntentProposal` before resolution and a guided, player-facing narration only after the reducer records an outcome. The narration input is a bounded snapshot of the resolved event and recorded campaign facts; it cannot mutate state, decide rules, or supply dice. When Apple Intelligence is unavailable, the app visibly retains deterministic play and labels the missing narration rather than silently substituting a cloud model.

## Module dependency direction

```text
App -> AI GM / Persistence / Multiplayer / Rules Packs / Rules Engine / Dice Engine
AI GM -> Rules Engine -> Dice Engine -> Core
Persistence / Multiplayer / Rules Packs -> Core
```

No engine module imports the UI. No rules pack imports a publisher SDK. No AI module writes storage or sync state.

## Scaffold versus delivered behavior

`project.yml` is the source for the eight product targets plus the test target. `Multiplayer/Sources/Sync.swift` currently defines `CampaignEventTransport` and `SyncMode` only; there is no network transport or shared-session UI yet. Event identifiers and timestamps alone do not provide ordering, authorization, idempotency, or conflict resolution. Those must be specified and tested before claiming multiplayer support.

The generic 2d20 and dice-pool entries in `RulesPacks/Sources/RulesPacks.swift` are descriptors, not implementations of published Star Trek or Marvel mechanics. Published-system support requires an explicit edition, permitted source material, a rules adapter, and conformance tests. Warcraft-like fantasy can use the common engine with original world content; the scaffold does not grant rights to Warcraft settings or assets.

The scaffold preserves these extension boundaries while delivering the first solo slice. Completion of the full platform requires both actual multiplayer and additional playable systems.
