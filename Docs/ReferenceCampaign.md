# The Lantern Below — Reference Campaign Packet

**Pack:** `d20-fantasy` v0.1.0

**Content ownership:** Original AetherTable starter content. No third-party setting, character, rule text, monster, mark, or artwork is used.

## Purpose

This is not a lore bible. It is the smallest complete adventure needed to prove AetherTable’s product loop:

- enter a persistent world quickly;
- make choices with different kinds of stakes;
- see rules, dice, and consequences clearly;
- meet recurring people worth remembering;
- leave with an unfinished thread strong enough to return for.

It is designed for one player and three scenes. A successful playthrough should take three to five short sessions, not one exhausting evening.

## Player-facing premise

The river town of **Emberwake** has kept a brass lantern burning beneath its old bridge for generations. At dawn, the lantern goes out for the first time. The river begins flowing backward, carrying whispers from the drowned city below.

You are the one person who heard a voice inside the silence:

> *Bring back what we buried. Before it remembers your name.*

## Starter character contract

At campaign creation, a player chooses a name, an archetype, one defining detail, and one favored trait. The app never forces a class fantasy before the player has played.

### Traits

| Trait | Used for |
|---|---|
| **Might** | force, endurance, close danger, physical protection |
| **Wits** | investigation, craft, lore, perception, clever plans |
| **Presence** | courage, leadership, empathy, negotiation, will |

Assign **+2** to a favored trait, **+1** to another, and **+0** to the remaining trait.

### Archetypes

These are prompts, not locked classes. Each carries an edge usable once per scene.

| Archetype | Edge |
|---|---|
| **Warden** | After you protect someone from immediate harm, reduce the consequence by one step. |
| **Wayfinder** | Ask one concrete question about a path, place, or hidden danger; the GM answers from recorded world facts. |
| **Lorekeeper** | Declare a useful but ordinary item or remembered fact; add it to the journal if it does not contradict state. |
| **Envoy** | Once per scene, turn a hostile conversation into a tense negotiation before dice are rolled. |

### Starting state

```text
Health: 6 / 6
Resolve: 3 / 3
Inventory: personal token, travel pack, 10 silver marks
Relationships: none yet
Conditions: none
Quest: The Lantern Below (active)
```

## Owned starter rules

### The core check

When failure would change the situation, roll:

```text
1d20 + relevant trait + any declared edge
```

| Difficulty | Target | Meaning |
|---|---:|---|
| Steady | 10 | routine under pressure |
| Risky | 13 | meaningful resistance or uncertainty |
| Dire | 16 | danger, scarcity, or formidable opposition |
| Legendary | 19 | extraordinary without preparation or help |

### Results

| Result | Outcome |
|---|---|
| Total meets/exceeds target | Full success. The player gets what they attempted or a clear equivalent. |
| Total is 1–2 below target | Success with a cost: time, lost resource, exposure, a condition, or a new complication. |
| Total is 3+ below target | The attempt does not achieve its immediate goal, but the story moves forward through a revealed danger, hard choice, or changed position. Never a dead end. |
| Natural 20 | Full success plus a durable advantage recorded in state. |
| Natural 1 | The attempt still gives useful information, but the immediate consequence escalates. |

### Harm and conditions

Harm is only applied when a scene’s established danger can cause it. A consequence can do one of the following:

- reduce Health by 1–2;
- reduce Resolve by 1;
- add a condition: **Shaken**, **Exposed**, **Winded**, or **Marked**;
- consume or damage a tracked item;
- advance a scene threat.

At 0 Health, the character is **Down**, not dead. The next scene becomes rescue, capture, escape, or recovery based on recorded context. AetherTable does not erase a campaign because of one unlucky roll.

### Engine invariants

- The action resolver receives the action, trait, difficulty, declared edge, and deterministic dice seed.
- The resolver emits a structured `actionResolved` event with total, outcome band, costs, and state changes.
- GM prose is generated only after that event. It cannot add a different reward, injury, fact, NPC motive, or roll result.
- All claimed world facts must be in structured state or a prior event.

## World state at campaign start

### Locations

| ID | Location | Established facts |
|---|---|---|
| `emberwake.square` | Bridge Square | The brass lantern hangs beneath the old bridge; the river is flowing backward. |
| `emberwake.archive` | Flooded Archive | Sealed civic records are stored below the town hall; access requires the archivist’s key or a clever route. |
| `emberwake.bridge` | Old Bridge | Below the bridge is a stone stair that appears only when the lantern is dark. |
| `vault.threshold` | Lantern Vault | A drowned chamber beneath the river; it reacts to names, promises, and light. |

### Recurring NPCs

| ID | NPC | Public face | Private pressure | Initial relationship |
|---|---|---|---|---|
| `npc.sera` | Sera Vale, bridgekeeper | Steady, practical guardian of the bridge | Her brother disappeared beneath the bridge years ago; she fears the town learned nothing | Neutral |
| `npc.oren` | Oren Pell, town archivist | Fussy keeper of municipal history | He helped hide the record of the drowned city to protect Emberwake’s founders | Guarded |
| `npc.nym` | Nym-of-the-Reed, river emissary | A voice in the current | Bound to the vault, wants release but not the destruction of Emberwake | Unknown |

### Campaign facts

```text
lantern.status = extinguished
river.direction = upstream
vault.status = sealed
town.truth = unknown
threat.clock = 0 / 4
```

## Scene 1 — The dark beneath the bridge

### Entry

The player begins in Bridge Square as townspeople wake to the backward river. Sera is holding the bridge closed. A child has dropped a paper boat into the water; it is drifting upstream toward the dark lantern.

### Scene question

**Will the player investigate the lantern before fear turns the town against the river?**

### Meaningful approaches

| Approach | Typical trait | Target | Success | Cost/failure forward |
|---|---|---:|---|---|
| Climb below the bridge | Might | 13 | Reach the lantern and find its warm, empty socket | Winded or exposed to the rising current; still finds a brass shard wedged behind the lantern. |
| Study the backward current | Wits | 10 | Learn it flows toward the Flooded Archive, not the sea | A whisper speaks the character’s name; add `Marked` or advance threat. |
| Calm the gathering crowd | Presence | 13 | Sera trusts the player enough to share what she saw: a stair below the bridge | The crowd disperses badly; Oren arrives demanding the matter be contained. |
| Retrieve the paper boat | Any plausible trait | 10 | Find a child’s drawing of a door beneath the bridge | Take minor harm or lose time; the drawing remains evidence. |

### Required state outputs

- `clue.brassShard` or `clue.stairDrawing` or `clue.archiveCurrent` becomes true.
- At least one NPC relationship changes.
- `scene.darkBridge.completed = true`.
- `quest.next = "Find why the Lantern Below was extinguished."`

### Scene-end recap seed

> The Lantern Below has gone dark, and the river is carrying its secrets upstream. You hold the first clue, but Emberwake is already choosing what it is willing to fear.

## Scene 2 — What Emberwake buried

### Entry

The player needs the town’s buried history. Oren controls the formal path into the Flooded Archive; the old waterworks offer an unofficial path. Sera can help only if the player has earned enough trust.

### Scene question

**Will the player uncover the truth without becoming part of the cover-up?**

### Revealed truth

Fifty years ago, Emberwake dammed a subterranean river through the Lantern Vault and bound its keeper, Nym-of-the-Reed, with the names of the town’s founding families. The lantern was not a ward against monsters; it was a promise that the town would remember what it took. Oren’s predecessors changed the record to a story of heroic protection.

### Branches

| Route | Requirement | What it reveals | Consequence space |
|---|---|---|---|
| Ask Oren directly | Presence 13 or strong trust | A redacted ledger and Oren’s confession | He asks the player to preserve the town’s peace, creating a promise choice. |
| Enter through waterworks | Wits 13 or Wayfinder edge | A maintenance map and submerged name-plates | Threat advances; the player may emerge Marked. |
| Follow Sera’s memory | Relationship: Sera trusted | Her brother left a note: “The lantern is a debt, not a lock.” | Sera asks to descend with the player in the next scene. |

### Required state outputs

- `town.truth = "vaultDebt"`.
- `clue.foundingNames = true` or `clue.brotherNote = true`.
- Player takes, refuses, or defers a promise to Oren and/or Sera.
- `scene.floodedArchive.completed = true`.
- `quest.next = "Descend to the Lantern Vault and choose what Emberwake owes."`

### Scene-end recap seed

> The lantern was never simply a shield. Emberwake made a promise to the river and buried the cost of keeping it. The vault is open now, and someone must decide what a debt becomes after fifty years.

## Scene 3 — The vault remembers

### Entry

The stone stair beneath Old Bridge descends through water that hangs in the air like glass. At the threshold waits Nym-of-the-Reed: not a monster, not a saint, and not free.

### Scene question

**What does the player choose when every honest resolution costs someone something?**

### The final choice

The engine records one of these as a player decision; the GM never selects it.

| Choice | Mechanical resolution | Durable consequence |
|---|---|---|
| Renew the promise | Presence 16; may spend 1 Resolve to include the player’s own name in the vow | Lantern returns, river settles, player is `BoundToTheLantern`; Nym remains but terms change. |
| Reveal the debt | Presence or Wits 13; requires `town.truth = vaultDebt` | Lantern remains dark temporarily; town learns the truth; threat clock resets to 2 as consequences begin. |
| Break the binding | Might or Wits 16; costs 2 Resolve or a valuable item | Nym is freed; the river changes course; Emberwake survives only through a new campaign arc of rebuilding. |
| Bargain for time | Presence 13 | Gain one season of calm, but record a concrete future price; the campaign opens its next arc with a ticking promise. |

### Required state outputs

- `vault.status` becomes `renewed`, `revealed`, `broken`, or `deferred`.
- `lantern.status` changes consistently with the choice.
- A relationship with Sera, Oren, and Nym is recorded.
- The first arc ends with an explicit next-world question, not a generic “adventure continues.”

### End recap seed

> You chose what Emberwake would remember. The river answered. But a debt does not disappear merely because someone finally names it.

## Implementation packet

### Minimum structured state additions

```text
Character:
  traits: { might: 0..2, wits: 0..2, presence: 0..2 }
  health: Int
  resolve: Int
  inventory: [Item]
  conditions: [Condition]
  archetypeEdge: EdgeState

Campaign world:
  locationID: String
  quest: { id, stage, objective }
  facts: [String: ScalarValue]
  relationships: [NPCID: -2...2]
  sceneProgress: [SceneID: SceneStatus]
  threatClock: { current, maximum }
```

### Required event kinds

```text
campaignCreated
characterCreated
sceneEntered
intentProposed
actionResolved
worldFactSet
resourceChanged
conditionChanged
relationshipChanged
questUpdated
choiceCommitted
noteAdded
```

### Acceptance scenarios

1. A fresh player can create a character and reach the first meaningful roll in under five minutes.
2. Every Scene 1 approach produces a clue and a usable next action; failure cannot soft-lock progress.
3. Reloading after any resolution restores character resources, clue state, relationships, and the recap exactly.
4. A narration test that claims the lantern is lit before a `choiceCommitted` event is rejected by the GM boundary.
5. The four Scene 3 endings produce different structured state and different continuation hooks.

## What this packet intentionally does not answer

- Full combat tactics, enemy stat blocks, leveling, crafting, or an exhaustive spell catalog.
- A universal character system for all future rules packs.
- The ultimate fate of Emberwake beyond the first arc.

Those features would create surface area before we know that players want to return to this world. The next engineering job is to make these three scenes mechanically playable, not to invent a hundred more rooms.
