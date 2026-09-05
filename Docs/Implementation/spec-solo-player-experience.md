---
title: Complete the solo fantasy player experience
type: feature
created: 2026-09-04
status: superseded
baseline_commit: 84203d8
context: []
---

# Complete the solo fantasy player experience

Superseded by `spec-open-world-first-edition.md` following Chris's explicit correction: multiple classes, no suggested actions, open free-form play, model as storyteller and Dungeon Master. This foundation is reusable but is not the accepted first-edition outcome.

## Intent

**Problem:** The current phone prototype resolves a short SRD adventure but exposes only one scrolling scene. It lacks the supporting player surfaces and reliable failure/recovery behavior required to play and return with confidence.

**Approach:** Deliver a cohesive native solo adventure loop from campaign library through character naming, scene choices and resolution, recovery, journal, character/rules reference, and a permanent ending. Chris explicitly delegates implementation and UI decisions on 2026-09-04 and removes multiplayer and non-D&D genres from current scope. Proceed through local implementation and verification under that authorization.

## Boundaries & Constraints

**Always:** Use the existing SRD 5.2.1 mechanical subset and original Lantern Below setting. Be transparent that the character is a level-one Fighter quickstart, not a complete class builder. Native SwiftUI, readable prose, usable Dynamic Type/VoiceOver, large touch targets, supporting information one tap away. Engine owns outcomes, saves commit before presentation, AI narrates committed outcomes only. Preserve existing saves and the eight-module structure. Keep unavailable AI separate from useful authored narrative.

**Ask First:** External publication, cloud provisioning, paid services, expanding current genre or multiplayer scope.

**Never:** Fake class/spell options, infer dice from AI text, overwrite an existing campaign when starting another, silently substitute in-memory storage after disk failure, expose debug fields as the main story, claim full D&D rules support.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected behavior |
|---|---|---|
| Fresh launch | No saves | Adventure introduction and create-character path |
| Character creation | Trimmed nonempty name | Named Fighter with published profile stats and original campaign saved before navigation |
| Returning | One or multiple saved campaigns | Library with resume and persisted location/objective/resources |
| Player turn | Valid attack or scene choice | Exactly one resolution, visible dice/modifier/target/outcome and consequence |
| Enemy turn | Active enemy | Clear continue action resolves only that turn |
| Repeated tap | Resolution or narration pending | Duplicate mutation blocked in model and disabled UI |
| Defeat | Recovery stage | Shelter narrative and durable route back into play; no dead end |
| Vault prerequisite | Missing truth | Choice disabled with reason; engine cannot commit it |
| Ending | Quest complete | Distinct ending and recorded effects, journal and library still usable |
| AI unavailable | Any resolved outcome | Authored consequence remains readable; separate availability status |
| Save failure | Disk error | Previous committed state preserved, actionable error, retry possible |
| Corrupt save | Decode fails | Explicit error, other valid campaigns remain available; corrupt file retained |
| Notes | Nonempty trimmed text | Durable note visible after reload without overwriting recap |

## Code Map

- `AetherTableApp/Sources/` — replace monolithic view with library, creation, adventure, character, journal, rules and supporting components; separate observable model.
- `RulesPacks/Sources/` — deterministic campaign orchestration/presentation and recovery, existing mechanics reused.
- `Persistence/Sources/CampaignStore.swift` — campaign discovery, durable storage and explicit errors without breaking saved JSON.
- `AIGM/Sources/AIGM.swift` — bounded grounded narration, available actions supplied when classifying intent.
- `AetherTableTests/Sources/` — campaign/persistence failure and full-arc behavior tests.
- `project.yml` — source discovery and appropriate test dependencies; regenerate native project.
- `Docs/PRD.md`, `Docs/Architecture.md`, `README.md` — current solo scope and honest tested capability.

## Tasks & Acceptance

**Execution:**
- [ ] Build campaign library and nameable Fighter introduction without replacing old saves.
- [ ] Build coherent adventure UI with readable authored scenes, valid actions, dice detail and error/AI states.
- [ ] Expose character abilities, HP, equipment, objective, relationships, rules attribution/search and chronological journal with notes.
- [ ] Implement recovery, ending, duplicate-action protection, persist-before-publish and guarded scene transitions.
- [ ] Test new behavior, compile app and visually inspect simulator screens.
- [ ] Update scope documentation and record independent review findings and verification.

**Acceptance Criteria:**
- Given a fresh install, when Chris names a Fighter and starts, then the saved character and opening scene are visible with a clear next action.
- Given a valid action, when it resolves, then the recorded roll and consequence are inspectable and state advances once.
- Given victory or defeat, when the encounter ends, then a valid path reaches Archive, Vault and a permanent ending.
- Given a save failure, when an action is attempted, then the last committed campaign remains authoritative and an error is shown.
- Given saved progress and notes, when the app reopens, then the selected campaign can resume with matching resources, choices and journal.
- Given unavailable Apple Intelligence, when play continues, then authored story and deterministic mechanics remain playable.

## Verification

Existing and added Swift Testing suite on installed iPhone simulator; Xcode 27 app build; independent adversarial review; simulator visual/interaction pass for library, creation, adventure and supporting sheets. Physical-device installation is not necessary to validate this local build. No live AI quality claim without on-device evidence.
