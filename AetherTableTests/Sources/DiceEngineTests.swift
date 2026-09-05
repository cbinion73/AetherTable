import DiceEngine
import AetherTableCore
import Foundation
import RulesEngine
import RulesPacks
import Persistence
import Testing

@Test func seededRollsAreRepeatable() throws {
    let expression = DiceExpression(count: 2, sides: 20, modifier: 3)
    let first = try DiceEngine.roll(expression, seed: 42)
    let second = try DiceEngine.roll(expression, seed: 42)
    #expect(first == second)
}

@Test func campaignEventsPersistAndRestore() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try FileCampaignStore(directory: directory)
    var campaign = CampaignState(title: "The First Thread", rulesPackID: "d20-fantasy")
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .actionResolved, payload: ["verb": "attempt", "detail": "open the sealed door", "total": "16"]))
    try await store.save(campaign)
    let restored = try await store.load(id: campaign.id)
    #expect(restored?.id == campaign.id)
    #expect(restored?.events.first?.payload == campaign.events.first?.payload)
    #expect(restored?.recap.contains("16") == true)
}

@Test func rulesPacksControlTheCheckShape() {
    let campaign = CampaignState(title: "Test", rulesPackID: "momentum-2d20")
    let pack = BuiltInRulesPacks.all[1]
    let outcome = RulesEngine().resolve(intent: .init(verb: "scan", detail: "the nebula"), in: campaign, using: pack, seed: 42)
    guard case .accepted(let event) = outcome else { Issue.record("Expected accepted action"); return }
    #expect(event.payload["total"] != nil)
}

@Test func starterWorldStateBeginsWithAPlayableCharacter() {
    let hero = CharacterSheet(name: "Arden", archetype: "Wayfinder", definingDetail: "Hears the river speak.", favoredTrait: .wits)
    let world = WorldState(player: hero)
    #expect(world.locationID == "emberwake.square")
    #expect(world.quest.id == "lantern-below")
    #expect(world.player?.traits[.wits] == 2)
    #expect(world.player?.health == 6)
    #expect(world.facts["lantern.status"] == "extinguished")
}

@Test func reducerAppliesStarterCampaignFactsAndCapsResources() throws {
    var campaign = CampaignState(title: "The Lantern Below", rulesPackID: "d20-fantasy")
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .characterCreated, payload: ["name": "Arden", "archetype": "Wayfinder", "definingDetail": "Hears the river.", "favoredTrait": "wits"]))
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .worldFactSet, payload: ["key": "clue.brassShard", "value": "true"]))
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .resourceChanged, payload: ["resource": "health", "delta": "-8"]))
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .relationshipChanged, payload: ["npcID": "npc.sera", "delta": "7"]))
    #expect(campaign.world.player?.health == 0)
    #expect(campaign.world.player?.conditions.contains(.down) == true)
    #expect(campaign.world.facts["clue.brassShard"] == "true")
    #expect(campaign.world.relationships["npc.sera"] == 2)
}

@Test func reducerRejectsAnEventForAnotherCampaign() throws {
    var campaign = CampaignState(title: "One", rulesPackID: "d20-fantasy")
    let foreign = CampaignEvent(campaignID: CampaignID(), kind: .noteAdded, payload: [:])
    #expect(throws: CampaignReducerError.wrongCampaign) { try campaign.apply(foreign) }
}

@Test func lanternBelowFailureStillCreatesAClueAndAdvancesTheStory() throws {
    var campaign = CampaignState(title: "The Lantern Below", rulesPackID: "d20-fantasy")
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .characterCreated, payload: ["name": "Arden", "archetype": "Wayfinder", "favoredTrait": "wits"]))
    for event in LanternBelowSceneOne.enterEvents(for: campaign.id) { try campaign.apply(event) }
    let resolved = CampaignEvent(campaignID: campaign.id, kind: .actionResolved, payload: ["verb": "attempt", "detail": "I study the current.", "total": "4", "band": "miss"])
    try campaign.apply(resolved)
    for event in try LanternBelowSceneOne.consequenceEvents(choiceID: "study", resolved: resolved) { try campaign.apply(event) }
    #expect(campaign.world.facts["clue.archiveCurrent"] == "true")
    #expect(campaign.world.threatClock.current == 1)
    #expect(campaign.world.player?.conditions.contains(.marked) == true)
    #expect(campaign.world.sceneProgress[LanternBelowSceneOne.id] == .completed)
}

@Test func officialSRDReferenceIsSeparateAndCarriesAttribution() {
    let srd = SRD521RulesPack.descriptor
    #expect(!BuiltInRulesPacks.all.map(\.descriptor.id).contains(srd.id))
    #expect(srd.license?.sourceVersion == "5.2.1")
    #expect(srd.license?.licenseName == "Creative Commons Attribution 4.0 International")
    #expect(srd.license?.attribution.contains("Wizards of the Coast") == true)
}

@Test func diceStayWithinBounds() throws {
    let roll = try DiceEngine.roll(DiceExpression(count: 3, sides: 6, modifier: 0), seed: 9)
    #expect(roll.values.allSatisfy { (1...6).contains($0) })
}
