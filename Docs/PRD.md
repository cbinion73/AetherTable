# AetherTable Product Requirements Document

**Status:** Directional product contract

**Decision:** Build one excellent persistent solo campaign experience first. The architecture supports multiple systems; the product earns that complexity only after players return to the first one.

## 1. Product outcome

### The outcome Chris wants

A player who loves tabletop roleplaying but cannot reliably schedule a group can open AetherTable for 20–60 minutes, continue a living adventure immediately, make meaningful choices, roll real dice, leave at any moment, and return days later without losing the story, consequences, or emotional thread.

It should feel like sitting back down at a well-run table—not chatting with a generic fantasy bot and not operating a virtual tabletop alone.

### Product promise

> **Your campaign is always ready when you are.**

The GM remembers. The world changes. The rules are trustworthy. The next session starts with a sharp recap, not setup homework.

## 2. Customer and job to be done

### Primary player

An adult tabletop RPG fan who loves long-form campaigns and familiar systems but has fragmented time and unreliable group availability. They want solo play that respects their intelligence, choices, and the game’s mechanics.

### Job to be done

**When I have an unexpected 20–60 minutes and want the feeling of a real tabletop session, help me enter a meaningful ongoing adventure immediately, play a satisfying scene, and preserve it perfectly for later.**

### Alternatives

- Waiting for a scheduled group session.
- Solo gamebooks or video games with less improvisation.
- Generic AI chat, which lacks trusted rules and durable world state.
- Virtual tabletops, which solve remote play but still require a GM and scheduling.

## 3. Product thesis

The winning experience is not “AI tells stories.” AI can already do that.

The defensible experience is the combination of:

1. **Continuity** — an accurate, evolving campaign memory.
2. **Trust** — rules, dice, inventory, and consequences are deterministic and auditable.
3. **Presence** — an AI GM delivers scenes, NPCs, pressure, and recaps with personality.
4. **Low activation energy** — open, recap, choose, play.

AI is the GM’s creative layer. It is never the game’s source of truth.

## 4. Product principles

1. **Resume in under 15 seconds.** The continuation path matters more than a beautiful home screen.
2. **Every important state change is an event.** A campaign can be rebuilt, synced, reviewed, and trusted.
3. **The player owns the decision; the engine owns the outcome.**
4. **Narrative responds to resolution, never replaces it.** The GM narrates what the engine has already decided.
5. **One excellent first world beats four thin ones.** Rules packs are a platform capability, not a launch promise.
6. **Owned or licensed content only.** Inspiration is not authorization.
7. **Mobile is a session companion, not a desktop VTT shrunk onto a phone.**

## 5. V1 definition: the solo campaign loop

### V1’s one playable product

An original, owned **fantasy adventure pack** with a simple d20-based rules profile. It is not branded as compatible with any third-party game and contains no copied rule text, setting material, stat blocks, trademarks, or art.

The first campaign is a compact opening arc designed for three to five satisfying sessions. Its job is to prove that the player wants to come back—not to emulate an entire RPG catalog.

### Required player flow

```text
Open app
  -> Continue campaign
  -> 15–30 second recap: situation, stakes, allies, unresolved thread, current resources
  -> Choose / type an action
  -> Engine validates action and rolls visible, auditable dice
  -> GM narrates only the resolved outcome
  -> State, journal, and recap update automatically
  -> Player leaves at any moment
```

### V1 capabilities

| Capability | Must be true at release |
|---|---|
| Campaign creation | Player selects the original fantasy pack, names a campaign and character, and starts within minutes. |
| Character | Simple, legible sheet: identity, archetype, key traits, health/resources, inventory, conditions, and relationships. |
| Session recap | Automatically generated from event history; it must show current location, open objective, immediate threat, and material resources. |
| Play | Player can use suggested actions or free text. The AI classifies intent into an allowed action; the engine can reject unclear/illegal actions gracefully. |
| Dice | Every roll shows expression, individual dice, modifiers, total, and immutable audit seed. |
| World state | Locations, NPC relationships, quests, inventory, and conditions persist as structured state, not prose only. |
| Journal | Player can read a chronological event journal and add manual notes. |
| AI GM | Apple Foundation Models supplies constrained intent proposals, recaps, dialogue, and outcome narration. Unavailable devices retain a truthful non-AI fallback; the app does not pretend the GM worked. |
| Privacy | Solo campaign data is local by default. |

### Explicitly out of V1

- Multiplayer and shared campaign editing.
- Published or branded RPG rules and settings.
- An open-ended rule-authoring tool.
- Tactical maps, miniatures, fog of war, or virtual-tabletop features.
- Voice play, character art generation, marketplace, subscriptions, or social feeds.
- Four game systems.

## 6. Rules-pack strategy

### The platform contract

The platform owns campaign identity, event history, persistence, sync, player identity, dice audit records, and UI primitives. A rules pack owns only its owned/authorized data and small mechanical adapter.

```text
Shared platform kernel
  Campaign + character + world-state schemas
  Event store + recap inputs + dice audit trail
  Action UI + GM boundaries + sync contract

Rules pack
  Action vocabulary + character schema extensions
  Check / resolution definitions + conditions
  Narrative vocabulary + owned content
```

### Sequencing rule

Build the pack API while delivering V1, but ship only the original fantasy pack. Add a second pack only after V1 proves retention and the pack interface has survived real campaign use.

That second pack should be an original **starship exploration** experience to test whether the platform handles a fundamentally different play loop: command decisions, investigation, diplomacy, and crew consequences rather than dungeon combat. It must remain original until a license exists.

## 7. Architecture requirements

### Authority model

```text
Player input
  -> Foundation Models: structured proposal (never authoritative)
  -> Rules adapter: validate legal action and choose declared check
  -> Dice engine: deterministic audited result
  -> Reducer: append event and update canonical state
  -> Persistence / future sync: save and distribute the same event
  -> Foundation Models: narrate the resolved event
```

### Technical decisions

- **Client:** native SwiftUI iOS app, built with Xcode 27.
- **AI:** Apple Foundation Models using guided Swift generation and tool boundaries. Keep prompts/versioning/proposal transcripts separate from campaign truth.
- **Persistence:** start with a local event store and materialized campaign state. Migrate only when a clear data need requires SwiftData or CloudKit.
- **Multiplayer:** CloudKit-sharing feasibility spike follows solo validation; it may not alter rules authority or event semantics.
- **Rules:** Versioned pack manifest, declarative checks, explicit reducers, and a deterministic random seed per roll.
- **Observability:** local, privacy-respecting product events; never log player prose or campaign content by default.

## 8. Delivery plan and gates

### Gate 0 — Product contract and reference campaign

**Goal:** Define the first play experience before more engineering.

Deliverables:

- This PRD approved as the decision record.
- A short original reference campaign: premise, three scene sequence, named choices, fail-forward consequences, NPC motivations, and ending hook.
- A small d20-fantasy rules reference that we own: character traits, action types, resolution rules, health/resources, conditions, inventory, and encounter structure.
- A UI flow sketch for Continue, Recap, Scene, Action, Resolution, and Journal.

**Exit:** A human can play the opening scene on paper with no missing rule decisions.

### Gate 1 — Trustworthy solo core

**Goal:** Make the first session mechanically real without AI polish.

Deliverables:

- Campaign and character creation.
- Versioned structured world state and event reducer.
- Character sheet, inventory, conditions, quest state, and journal.
- Visible dice roller with reproducible test rolls.
- Scene/action flow using deterministic scripted content.
- Local save, reopen, and exact recap from state/events.

**Exit:** A player can complete the opening scene, kill/relaunch the app, resume exactly, and verify each roll and consequence.

### Gate 2 — AI GM integration

**Goal:** Make the core feel alive without giving the model authority.

Deliverables:

- Constrained Foundation Models schemas for action classification, recap, NPC dialogue, and post-resolution narration.
- Availability and error states that clearly distinguish unavailable Apple Intelligence from an engine outcome.
- Prompt versions, adversarial test inputs, token/context budget, and deterministic fallback behavior.
- Guardrails against the model fabricating mechanics, loot, facts, or roll results.

**Exit:** Test play confirms the GM is engaging while every material fact remains traceable to state/events.

### Gate 3 — The first campaign experience

**Goal:** Prove return value, not content volume.

Deliverables:

- Three-to-five-session reference campaign with endings and branch recovery.
- Session-start recap, quest log, relationship hints, and “what matters now” affordance.
- Playtest protocol with a small group of target players.
- Bug fixes based on observed confusion, dropped context, and weak moments.

**Exit:** Most playtesters voluntarily return for a second session without being coached.

### Gate 4 — Multiplayer feasibility and beta decision

**Goal:** Decide with evidence whether shared play is the next value layer.

Deliverables:

- CloudKit-sharing technical spike against the established event contract.
- Host/party authority model, conflict policy, reconnect behavior, and consent/privacy design.
- A two-player scene prototype only if the event model survives unchanged.

**Exit:** Either a validated, small multiplayer beta plan or an explicit decision to deepen solo first.

### Gate 5 — Second rules-pack validation

**Goal:** Prove “one platform, multiple worlds” only after the platform earns it.

Deliverables:

- Original starship-exploration pack using a materially different action and resolution model.
- Pack conformance tests and migration/versioning rules.

**Exit:** The second pack ships without a fork of campaign, sync, or AI-GM architecture.

## 9. Success measures

### Product-quality measures

- **Time to first meaningful choice:** under five minutes from a fresh install.
- **Resume reliability:** 100% in automated persistence/reducer tests.
- **Rules traceability:** 100% of material state changes link to an event and, when applicable, a roll.
- **Recap fidelity:** testers can accurately answer “where am I, what is at stake, and what should I do next?” after reading it.
- **Second-session return:** the leading product signal. Measure during closed playtest; do not invent a target before baseline data exists.

### Stop/revise signals

- Players describe it as “chatting with AI” rather than playing a game.
- Recaps or NPC/world facts contradict recorded events.
- Players cannot explain why a result happened.
- The first session requires frequent manual repair by the player.
- Building rules packs consumes more effort than deepening the first campaign.

## 10. Risks and decisions

| Risk | Product response |
|---|---|
| AI hallucinates facts or mechanics | Strict schemas; engine/reducer is authoritative; narration receives resolved facts only. |
| Apple Intelligence is unavailable | Truthful availability state and deterministic non-AI play; no hidden cloud-model substitution. |
| RPG IP exposure | Original owned starter content; legal review before all compatibility language or licensed materials. |
| Scope explosion | Gate-based delivery; no multiplayer/second pack until the preceding gate passes. |
| Solo play feels lonely | Prioritize recurring NPC relationships, consequences, and recap quality over map or content volume. |
| Multiplayer corrupts state | Event-sourced sync semantics are designed first; shared play waits until solo is stable. |

## 11. Immediate next artifact

Create the **reference campaign packet** for the original fantasy V1: a three-scene opening adventure and its small owned rules reference. That is the exact design input required to turn the current technical scaffold into a playable product.
