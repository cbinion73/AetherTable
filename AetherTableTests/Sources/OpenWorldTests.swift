import AetherTableCore
@testable import AetherTable
import AIGM
import Foundation
import Persistence
import RulesPacks
import Testing

@Test func fourDistinctPresetsHaveExpectedCoreResources() {
    let fighter = OpenWorldHero.preset(.fighter, name: "F"), rogue = OpenWorldHero.preset(.rogue, name: "R"), wizard = OpenWorldHero.preset(.wizard, name: "W"), cleric = OpenWorldHero.preset(.cleric, name: "C")
    #expect(fighter.maximumHitPoints == 12 && fighter.armorClass == 17 && fighter.secondWindUses == 2)
    #expect(rogue.maximumHitPoints == 10 && rogue.modifier(.dexterity) + rogue.skills["stealth", default: 0] == 7)
    #expect(wizard.maximumHitPoints == 8 && wizard.spellSlots == 2 && wizard.spells.contains("mage hand"))
    #expect(cleric.maximumHitPoints == 10 && cleric.armorClass == 16 && cleric.spells.contains("healing word"))
}
@Test func mundaneCreativeActionNeverRequiresDiceOrCombat() throws {
    let state = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"))
    let result = try OpenWorldEngine.resolve(.init(reason: "Ask about the baker’s sourdough"), in: state, seed: 1)
    #expect(result.adventure.hero == state.hero)
    #expect(result.adventure.opponents.isEmpty)
    #expect(!result.receipt.contains("d20"))
}
@Test func trainedCheckUsesCorrectExpertiseAndIsRepeatable() throws {
    let state = OpenWorldAdventure(hero: .preset(.rogue, name: "R"))
    let plan = WorldActionPlan(kind: "check", ability: "dexterity", skill: "stealth", difficulty: 13)
    let first = try OpenWorldEngine.resolve(plan, in: state, seed: 42)
    #expect(first == (try OpenWorldEngine.resolve(plan, in: state, seed: 42)))
    #expect(first.receipt.contains("+ 7"))
}
@Test func playerD20IsAppliedToAHeroCheck() throws {
    let state = OpenWorldAdventure(hero: .preset(.rogue, name: "Nim"))
    let plan = WorldActionPlan(kind: "check", ability: "dexterity", skill: "stealth", difficulty: 12)
    let result = try OpenWorldEngine.resolve(plan, in: state, seed: 42, playerD20: 17)
    #expect(plan.requiresPlayerD20Roll)
    #expect(result.receipt.contains("selected 17"))
    #expect(result.outcome == "Success")
}
@Test func repeatedOpeningIsRemovedBeforeTheNextSceneIsSaved() {
    let earlier = AdventureMessage(role: "gm", text: "Rain taps the lantern glass. The ferryman grips the chain.")
    let next = AdventureTurn.removingRepeatedOpening("Rain taps the lantern glass. The ferryman grips the chain. A bell rings below the black water.", transcript: [earlier])
    #expect(next == "A bell rings below the black water.")
}
@Test func heroMentionOutsideDialogueIsNotAcceptedAsWorldNarration() {
    let kept = AdventureTurn.worldOnlyPrefix("The bakery bell shivers in its frame. Rowan steps through the door and asks for bread.", heroName: "Rowan")
    #expect(kept == "The bakery bell shivers in its frame.")
}
@Test func aBriefDirectNPCReplyIsAValidStoryTurn() throws {
    let state = OpenWorldAdventure(hero: .preset(.cleric, name: "Liora"))
    let resolution = try OpenWorldEngine.resolve(.init(), in: state, seed: 1)
    let updated = try AdventureTurn.finish(playerText: "Is the bread fresh?", resolution: resolution, story: .init(prose: "The baker nods. \"Fresh this morning.\"", location: "Bakery", memories: []))
    #expect(updated.transcript.last?.text == "The baker nods. \"Fresh this morning.\"")
}
@Test func magicMissileSpendsSlotAndAlwaysDoesThreeDarts() throws {
    let state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    let plan = WorldActionPlan(kind: "spell", tool: "magic missile", target: "Shade", targetHitPoints: 60)
    let result = try OpenWorldEngine.resolve(plan, in: state, seed: 7)
    #expect(result.adventure.hero.spellSlots == 1)
    let hp = try #require(result.adventure.opponents["shade"]?.hitPoints)
    #expect([6, 9, 12, 15].contains(60 - hp))
    #expect(!result.receipt.contains("d20"))
}
@Test func exhaustedSlotsAndUnknownSpellsCannotChangeState() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W")); state.hero.spellSlots = 0
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(.init(kind: "spell", tool: "magic missile", target: "Shade"), in: state, seed: 7) }
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(.init(kind: "spell", tool: "wish"), in: state, seed: 7) }
    #expect(state.hero.spellSlots == 0 && state.opponents.isEmpty)
    let cantrip = try OpenWorldEngine.resolve(.init(kind: "spell", tool: "mage hand"), in: state, seed: 7)
    #expect(cantrip.adventure.hero.spellSlots == 0)
}
@Test func healingCanRestoreWoundedNPCWithoutMakingThemHostile() throws {
    let state = OpenWorldAdventure(hero: .preset(.cleric, name: "C"))
    var plan = WorldActionPlan(kind: "spell", tool: "cure wounds", target: "Lysa", targetHitPoints: 12)
    plan.targetCurrentHitPoints = 1
    let result = try OpenWorldEngine.resolve(plan, in: state, seed: 3)
    let lysa = try #require(result.adventure.opponents["lysa"])
    #expect(lysa.hitPoints > 1 && lysa.hitPoints <= 12)
    #expect(!lysa.hostile)
    #expect(result.adventure.hero.spellSlots == 1)
}
@Test func establishedActorStatsCannotBeChangedByLaterPlans() throws {
    var state = OpenWorldAdventure(hero: .preset(.cleric, name: "C"))
    state.opponents["shade"] = .init(name: "Shade", armorClass: 14, hitPoints: 60, maximumHitPoints: 60, saveModifier: 3, attackBonus: 4, damageSides: 8, hostile: true)
    let result = try OpenWorldEngine.resolve(.init(kind: "spell", tool: "sacred flame", target: "Shade", targetArmorClass: 5, targetHitPoints: 1, targetSaveModifier: -2), in: state, seed: 2)
    #expect(result.adventure.opponents["shade"]?.armorClass == 14)
    #expect(result.receipt.contains("+ 3 versus DC 13"))
}
@Test func rogueSneakAttackRequiresItsActualConditions() throws {
    let state = OpenWorldAdventure(hero: .preset(.rogue, name: "R"))
    var ordinary = WorldActionPlan(kind: "weapon", tool: "shortbow", target: "Shade", targetArmorClass: 5, targetHitPoints: 60)
    let normal = try OpenWorldEngine.resolve(ordinary, in: state, seed: 42)
    #expect(!normal.receipt.contains("Sneak Attack"))
    ordinary.adjacentAlly = true
    let aided = try OpenWorldEngine.resolve(ordinary, in: state, seed: 42)
    if aided.outcome != "Failure" { #expect(aided.receipt.contains("Sneak Attack")) }
    ordinary.disadvantage = true
    #expect(!(try OpenWorldEngine.resolve(ordinary, in: state, seed: 42)).receipt.contains("Sneak Attack"))
}
@Test func shortRestNeverGrantsLongRestResources() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W")); state.hero.spellSlots = 0; state.hero.hitPoints = 1
    let first = try OpenWorldEngine.resolve(.init(kind: "rest", tool: "short rest"), in: state, seed: 4)
    #expect(first.adventure.hero.spellSlots == 1)
    let second = try OpenWorldEngine.resolve(.init(kind: "rest", tool: "short rest"), in: first.adventure, seed: 5)
    #expect(second.adventure.hero.spellSlots == 1)
    #expect(second.adventure.hero.hitPoints == first.adventure.hero.hitPoints)
    let long = try OpenWorldEngine.resolve(.init(kind: "rest", tool: "long rest"), in: second.adventure, seed: 6)
    #expect(long.adventure.hero.spellSlots == 2 && long.adventure.hero.hitPoints == 8)
}
@Test func retrievalFindsOldPromisesAndArchiveStaysIntact() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    state.transcript.append(.init(role: "gm", text: "Baker Iven promised to pay apprentice Lysa three silver coins by moonrise."))
    for i in 0..<60 { state.transcript.append(.init(role: "gm", text: "Another quiet mile on road \(i).")) }
    let prompt = state.context(for: "Did Iven pay Lysa?")
    #expect(prompt.contains("three silver coins"))
    #expect(prompt.count <= 6500)
    #expect(state.transcript.count == 61)
    let encoded = try JSONEncoder().encode(state)
    #expect(try JSONDecoder().decode(OpenWorldAdventure.self, from: encoded) == state)
}
@Test func memoryUpdatePreservesPreviousDetailAndRejectsInvalidCategory() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    state.memories.append(.init(id: "person.iven", category: "person", name: "Iven", detail: "Owes Lysa three coins."))
    let resolution = try OpenWorldEngine.resolve(.init(), in: state, seed: 1)
    let result = try AdventureTurn.finish(playerText: "I ask Iven about Lysa.", resolution: resolution, story: .init(prose: "Iven sets three coins on the table.", location: "Bakery", memories: [.init(id: "person.iven", category: "person", name: "Iven", detail: "Paid Lysa three coins.")]))
    #expect(result.memories.contains { $0.detail == "Owes Lysa three coins." && $0.status == "inactive" })
    #expect(throws: OpenWorldError.self) { try AdventureTurn.finish(playerText: "hello", resolution: resolution, story: .init(prose: "Hello.", location: "Bakery", memories: [.init(id: "hero", category: "hitPoints", name: "Hero", detail: "999")])) }
}

private actor ScriptedDungeonMaster: DungeonMaster {
    var plans = 0, stories = 0
    var failStory = false
    func failNextStory() { failStory = true }
    func counts() -> (Int, Int) { (plans, stories) }
    func plan(playerText: String, adventure: OpenWorldAdventure) async throws -> WorldActionPlan { plans += 1; return .init() }
    func tell(playerText: String, resolution: WorldResolution) async throws -> WorldStory {
        stories += 1
        if failStory { failStory = false; throw GameMasterError.unavailable("Injected storyteller failure") }
        return .init(prose: "Iven brushes flour from a blue tin. ‘Lysa has not been paid.’", location: "Iven’s Bakery", memories: [.init(id: "person.iven", category: "person", name: "Iven", detail: "Baker who owes Lysa wages.")])
    }
}
private actor CheckDungeonMaster: DungeonMaster {
    func plan(playerText: String, adventure: OpenWorldAdventure) async throws -> WorldActionPlan {
        .init(kind: "check", ability: "dexterity", skill: "stealth", difficulty: 12, reason: "The dockmaster is watching the alley.")
    }
    func tell(playerText: String, resolution: WorldResolution) async throws -> WorldStory {
        .init(prose: "The fog shifts around the crates.", location: "Emberwake Docks", memories: [])
    }
}
private actor ToggleStore: CampaignStore {
    var state: CampaignState?
    var fail = false
    func toggle() { fail.toggle() }
    func load(id: CampaignID) async throws -> CampaignState? { state }
    func save(_ campaign: CampaignState) async throws { if fail { throw CocoaError(.fileWriteOutOfSpace) }; state = campaign }
}
@MainActor @Test func storytellerFailureRetainsDraftAndRetriesSameResolution() async throws {
    let gm = ScriptedDungeonMaster(); await gm.failNextStory()
    let model = CampaignViewModel(store: InMemoryCampaignStore(), dungeonMaster: gm)
    await model.start(); #expect(await model.createAdventure(name: "W", characterClass: .wizard))
    let initial = model.campaign
    model.draft = "I visit the bakery and ask about Lysa."
    await model.submit()
    #expect(model.campaign == initial && !model.draft.isEmpty && model.error != nil)
    await model.submit()
    let counts = await gm.counts()
    #expect(counts.0 == 1 && counts.1 == 2)
    #expect(model.adventure?.transcript.count == 2 && model.draft.isEmpty)
}
@MainActor @Test func playerMustRollBeforeAResolvedCheckReachesTheStory() async throws {
    let model = CampaignViewModel(store: InMemoryCampaignStore(), dungeonMaster: CheckDungeonMaster())
    await model.start(); #expect(await model.createAdventure(name: "Nim", characterClass: .rogue))
    model.draft = "I slip behind the dockmaster's crates."
    await model.submit()
    #expect(model.diceRoll?.title == "Dexterity check")
    #expect(model.adventure?.transcript.isEmpty == true)
    model.rollDice()
    try await Task.sleep(for: .seconds(1))
    #expect(model.diceRoll?.rolledD20 != nil && model.diceRoll?.resolution != nil)
    model.continueAfterDice()
    try await Task.sleep(for: .milliseconds(100))
    #expect(model.adventure?.transcript.count == 2 && model.draft.isEmpty)
}
@MainActor @Test func saveFailureRetriesPreparedStoryWithoutAnotherModelTurn() async throws {
    let gm = ScriptedDungeonMaster(), store = ToggleStore()
    let model = CampaignViewModel(store: store, dungeonMaster: gm)
    await model.start(); #expect(await model.createAdventure(name: "W", characterClass: .wizard))
    await store.toggle()
    model.draft = "I visit the bakery."
    await model.submit()
    #expect(model.adventure?.transcript.isEmpty == true)
    await store.toggle(); await model.submit()
    let counts = await gm.counts()
    #expect(counts.0 == 1 && counts.1 == 1)
    #expect(model.adventure?.transcript.count == 2)
}
@MainActor @Test func noteAddedBetweenFailedTurnAndRetryIsNotOverwritten() async throws {
    let gm = ScriptedDungeonMaster(); await gm.failNextStory()
    let model = CampaignViewModel(store: InMemoryCampaignStore(), dungeonMaster: gm)
    await model.start(); #expect(await model.createAdventure(name: "W", characterClass: .wizard))
    model.draft = "I ask about the bakery."
    await model.submit()
    #expect(await model.saveWorldNote("The blue tin matters."))
    await model.submit()
    #expect(model.adventure?.transcript.contains { $0.role == "note" && $0.text == "The blue tin matters." } == true)
    #expect(model.adventure?.memories.contains { $0.detail == "The blue tin matters." } == true)
}
@MainActor @Test func concurrentWorldSubmissionsCommitExactlyOneTurn() async throws {
    let gm = ScriptedDungeonMaster()
    let model = CampaignViewModel(store: InMemoryCampaignStore(), dungeonMaster: gm)
    await model.start(); #expect(await model.createAdventure(name: "W", characterClass: .wizard))
    model.draft = "I visit the bakery."
    async let one: Void = model.submit()
    async let two: Void = model.submit()
    _ = await (one, two)
    #expect(model.adventure?.turn == 1 && model.adventure?.transcript.count == 2)
}
@Test func modelCannotCompleteUnestablishedQuestOrTakePlayerAgency() throws {
    let state = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"))
    let result = try OpenWorldEngine.resolve(.init(), in: state, seed: 1)
    #expect(throws: OpenWorldError.self) { try AdventureTurn.finish(playerText: "I ask about wages.", resolution: result, story: .init(prose: "Rowan thanks the baker and heads home.", location: "Bakery", memories: [])) }
    #expect(throws: OpenWorldError.self) { try AdventureTurn.finish(playerText: "I ask about wages.", resolution: result, story: .init(prose: "The baker stays silent.", location: "Bakery", memories: [.init(id: "quest.new", category: "quest", name: "Unknown quest", detail: "Done.", status: "completed")])) }
}
