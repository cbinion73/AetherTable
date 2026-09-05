---
title: Deliver the open-world solo first edition
type: feature
created: 2026-09-05
status: in-progress
baseline_commit: 84203d8
context: []
---

# Deliver the open-world solo first edition

## Intent

**Problem:** A fixed Fighter adventure and choices menu contradict Chris's explicit product requirements. The player must author their own actions, explore, pursue side quests and solve problems creatively, with Apple Intelligence acting as a captivating Dungeon Master.

**Approach:** Build and deliver a native solo D&D-first beta with four distinct level-one classes (Fighter, Rogue, Wizard, Cleric), an open conversation, model-led worldbuilding/storytelling, deterministic adjudication, and persistent campaign memory. Emberwake is a starting setting, not a finite decision tree. Chris authorizes continued local implementation and delivery for testing; routine design decisions are delegated. Multiplayer and other genres are out of scope.

## Boundaries & Constraints

**Always:** No suggested actions or choice menus anywhere in play. Free text is the primary input. GM considers creative approaches, dialogue, exploration, side quests, spells and combat; ordinary actions need no roll. Storytelling gives sensory specificity, recurring NPC motives, mystery, consequences and room for player agency. GM cannot dictate the player's thoughts, choices or dialogue. The model may propose a check and world developments; engine chooses dice, applies class modifiers/resources and validates mechanical changes. After adjudication the GM tells what happens and returns structured memory updates alongside prose.

**Always:** Persistent full transcript and structured memory for people, places, quests, inventory, established facts and resources. Bounded model context retrieves relevant old memories and recent turns without truncating the durable archive. All changes and both sides of a conversation save together; failed generation or disk save preserves prior committed state and user draft. Legacy saves remain readable and can enter free play without losing their history. World continuation never ends merely because an initial quest finishes.

**Always:** Character creation shows meaningful class differences and mechanics actually implemented. Core level-one weapons, trained checks, class resources and selected first-level spells resolve with SRD 5.2.1 procedures. Support creative noncombat spell use through GM adjudication. State the rules subset honestly in reference material, without turning play into a debug console. Model unavailability is an explicit recoverable state; do not substitute canned open-world dialogue or a cloud AI.

**Ask First:** External publication, spending, cloud provisioning, or expanding multiplayer/genre scope.

**Never:** Funnel text into fixed scene choices, offer action chips, erase saves, let AI supply dice totals/HP/spell slots, present mocked model output as live evidence, declare success from builds alone.

## I/O & Edge-Case Matrix

| Scenario | Expected behavior |
|---|---|
| Four classes | Distinct sheet, weapons, proficiency and class/spell resources persisted |
| Talk, explore, invent approach | GM responds to intent; no mandatory combat or prewritten route |
| Side quest or leave Emberwake | New place/quest/person retained; old threads remain in memory |
| Uncertain attempt | Audited d20 + valid character modifier versus bounded difficulty |
| Weapon/spell use | Deterministic attack/save/effect and resource expenditure; unavailable resources cannot be fabricated |
| Contradictory player claim | GM treats it as intent/dialogue, not permission to overwrite canonical statistics |
| Failed roll | GM narrates its consequence; it cannot change the recorded outcome |
| Long campaign | Full history on disk; relevant memory plus recent transcript in bounded prompt |
| AI error/cancel/save error | Prior save intact; draft retained; retry available; no duplicate turns |
| App reopen | Same transcript, quests, locations, inventory, HP and resources |

## Code Map

- `RulesPacks/Sources/OpenWorld*.swift` — versioned persistent adventure memory, four-class presets, validated actions and deterministic turn resolution.
- `AIGM/Sources/DungeonMaster.swift` — real Foundation Models GM planning/storytelling and memory schemas; injectable protocol for tests.
- `AetherTableApp/Sources/` — multi-class creation, conversation composer/transcript, live GM progress/cancel/error, character, memory/journal, rules and library. Remove story action menus.
- `Persistence/Sources/CampaignStore.swift` — retain atomic campaign storage/discovery.
- `AetherTableTests/Sources/` — classes, creative/no-roll turns, memory durability/retrieval, mechanical guards, concurrency and failures.
- `Package.swift`, `Tools/GMPlaytest/` — run the same GM and engine on the Mac's available Apple model to verify storytelling, creative intent and recall.
- `project.yml` — native app wiring and build settings; XcodeGen regeneration.
- `Docs/`, `README.md` — first-edition scope, test evidence, remaining known limitations, feedback handoff.

## Tasks & Acceptance

- [ ] Implement open-world memory and four playable class profiles/resources.
- [ ] Implement two-stage real GM: interpret proposed mechanics, engine adjudicates, model narrates and records world developments.
- [ ] Replace adventure action buttons with free-form conversation and preserve drafts/errors.
- [ ] Make character, inventory, quests, people, places, rules, journal and library reflect saved memory.
- [ ] Add deterministic engine/model-failure/persistence tests and run actual Apple-model creative-play/recall smoke checks.
- [ ] Review independently, inspect simulator UX, build/sign/install on connected iPhone and deliver feedback instructions.

Given a player who declines the starting mystery and explores elsewhere, when they type that intent, the GM must follow it and save the changed setting. Given a named NPC or promise from earlier play, when that thread returns, memory retrieval must make it available to the GM. Given failed mechanics, the storyteller must preserve the outcome. Given any supported class, that character must have working class-appropriate actions through the same free-text loop. Given an unavailable model, the game must explain how to retry while preserving the campaign.

## Verification

Xcode27 simulator build and tests; deterministic scripted GM tests; real Foundation Models Mac playtest; independent review; manual native UI checks; signed device build/install. Report observed results separately from mocked tests. First edition means a testable open-world beta, not implementation of every rule, class and spell in the full D&D catalog.
