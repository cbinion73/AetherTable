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

`CampaignState` is a compact materialized view. `CampaignEvent` is the durable audit trail. Each event carries a stable identifier and date so a future sync transport can merge and order events without making the AI authoritative.

The first persistence adapter is local and replaceable. CloudKit sharing is the expected Apple-native multiplayer candidate, but it is an implementation choice for the next milestone, not an unearned claim in this scaffold.

## Rules packs

Every pack identifies itself by an owned identifier and version. It supplies a mechanic family, a list of declared actions, and UI/narrative vocabulary. The platform owns identities, campaigns, dice audit records, events, persistence, and sync.

Rules Packs must only contain material we own or are licensed to distribute. A “compatible with” claim is a legal/product decision, not an engineering convenience; do not add publisher marks, setting names, protected stat blocks, or rule text to a pack without rights review.

### Phone-native rules retrieval

Rules packs ship as compact structured records plus an offline deterministic search index. The Rules Engine addresses records by stable identifier and never delegates adjudication to retrieval. Full-text search serves the player and AI GM only when a rule needs to be located or explained; every result includes its rules version, source section, and source page. Semantic/vector retrieval is deferred until campaign-memory evidence shows it improves player questions beyond this local, source-cited path.

## Apple Intelligence

`FoundationModelsGM` is conditionally compiled for Apple platforms that provide Foundation Models. Its output must decode into an owned, small Swift type such as `GMIntentProposal`. Tool calls should be the only route from a model proposal to platform behavior. The first implementation is a safe unavailable fallback so the project builds before the full Apple Intelligence integration is added.

## Module dependency direction

```text
App -> AI GM / Persistence / Multiplayer / Rules Packs / Rules Engine / Dice Engine
AI GM -> Rules Engine -> Dice Engine -> Core
Persistence / Multiplayer / Rules Packs -> Core
```

No engine module imports the UI. No rules pack imports a publisher SDK. No AI module writes storage or sync state.
