---
title: 'GM scene quality guard'
type: 'bugfix'
created: '2026-09-05'
status: 'in-progress'
baseline_commit: 'd00baceb716e300dd7264fdb05187f6e9cf7e8aa'
context:
  - '/Users/chris/Documents/Codex/AetherTable/Docs/Architecture.md'
  - '/Users/chris/Documents/Codex/AetherTable/Docs/RulesPacks/Permitted-D20-Sources.md'
---

<frozen-after-approval reason="human-owned intent — do not modify unless human renegotiates">

## Intent

**Problem:** Phone campaigns show a concrete GM failure: it repeats catchphrases and ominous imagery, conflates NPCs, and responds to plain questions with more cryptic non-answers. The current exact-opening filter permits repeated ideas anywhere else in a response, while the memory extractor can preserve and amplify those stale fragments.

**Approach:** Give the narrator a compact, binding scene card before generation: place, named people, live facts, and recent exchange. Enforce scene-level novelty and direct-question resolution before a reply is saved. Preserve open-ended play and legitimate secrets, but require a specific, in-character answer or a clearly motivated refusal whenever the player asks a plain question. Memory updates must be limited to material changes in that same exchange.

## Boundaries & Constraints

**Always:** Keep player action authoritative; retain Apple Intelligence as the narrator; preserve deterministic engine receipts and retry safety; compare new narration against recent GM content semantically enough to catch repeated dialogue and distinctive phrases; maintain stable NPC identity, location, and already-established relationships; retain mysteries only when an NPC has a concrete reason to withhold information.

**Ask First:** Adding any remote model, moderation service, analytics collection, or authored fallback narration beyond a short error/retry explanation.

**Never:** Turn every answer into exposition, force a quest, replace free-form conversation with fixed choices, silently alter saved campaign history, or claim response quality is fixed without testing the exact phone failure pattern.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Direct question | Player asks an established barkeep why they repeat a phrase | Reply plainly explains it, or gives a concrete in-character reason for refusal | Reject a non-answer/repetition and retry with same resolution |
| Repeated motif | Recent GM transcript contains a catchphrase or distinct phrase | New reply does not reuse it or paraphrase it as fresh information | Reject before transcript/memory save |
| NPC continuity | Player examines a tavern object with barkeep present | Response keeps the barkeep and location unless an explicit change occurs | Reject contradictory unstaged identity/location shifts |
| Legitimate secret | NPC cannot safely reveal an answer | NPC names the reason or stakes without cryptic filler | Preserve playable uncertainty without fabricated facts |
| Memory extraction | New reply adds no material world fact | No new memory entry is created | Existing facts remain unchanged |

</frozen-after-approval>

## Code Map

- `AIGM/Sources/DungeonMaster.swift` -- narration instructions, transcript guard, and fact extraction boundary.
- `RulesPacks/Sources/OpenWorldState.swift` -- persisted transcript and world memory used for continuity.
- `AetherTableTests/Sources/StoryBoundaryTests.swift` -- narration persistence and player-agency regression coverage.
- `AetherTableTests/Sources/OpenWorldTests.swift` -- deterministic world-state resolution fixtures.

## Tasks & Acceptance

**Execution:**

- [ ] `AIGM/Sources/DungeonMaster.swift` -- add deterministic recent-phrase/answerability/continuity validation before save; strengthen narrator and archivist instructions to prevent stale-memory restaging.
- [ ] `AetherTableTests/Sources/StoryBoundaryTests.swift` -- add the captured festival/tavern repetition cases, direct-question cases, legitimate-secret case, and no-partial-save assertions.
- [ ] `AetherTableTests/Sources/OpenWorldTests.swift` -- add persistence regression proving a rejected narration leaves transcript, memories, and location unchanged.
- [ ] `Docs/Implementation/spec-playable-races-and-classes.md` -- retain the pending expansion separately; do not mark it delivered while its review findings remain open.

**Acceptance Criteria:**

- Given the seven-turn phone transcript’s repeated catchphrase, when a new GM reply repeats or rephrases it as new information, then the reply is rejected and campaign state is unchanged.
- Given a player asks a plain question of an established NPC, when the NPC knows the answer, then the accepted reply addresses the question concretely in character.
- Given an NPC must keep a secret, when it refuses, then the reply states a present motive, limitation, or stake rather than generic cryptic language.
- Given a reply introduces no material fact, when it is archived, then it adds no redundant memory.
- Given a retry follows a quality rejection, when the next response succeeds, then the player’s original intent and deterministic resolution are preserved.

## Spec Change Log

## Design Notes

The guard is intentionally content-aware but deterministic: it blocks repeated distinctive language and unsupported scene changes rather than attempting to score prose style. “I cannot tell you because the marshal is listening” is a valid secret. “The wind knows, if you dare” after several prior evasions is not.

## Verification

**Commands:**

- `DEVELOPER_DIR=/Users/chris/Downloads/Xcode-beta.app/Contents/Developer xcodebuild -quiet -project AetherTable.xcodeproj -scheme AetherTable -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath work/GMQualityTests build-for-testing` -- expected: app and all new tests compile.
- `DEVELOPER_DIR=/Users/chris/Downloads/Xcode-beta.app/Contents/Developer xcodebuild -quiet -project AetherTable.xcodeproj -scheme AetherTable -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath work/GMQualityTests test-without-building` -- expected: all tests pass.
- `DEVELOPER_DIR=/Users/chris/Downloads/Xcode-beta.app/Contents/Developer xcodebuild -quiet -project AetherTable.xcodeproj -scheme AetherTable -destination 'id=48649F2F-8CD2-554E-A004-A05C5662DED0' -derivedDataPath work/GMQualityPhone build` -- expected: signed phone build succeeds.
