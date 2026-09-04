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
    campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .actionResolved, payload: ["verb": "attempt", "detail": "open the sealed door", "total": "16"]))
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

@Test func diceStayWithinBounds() throws {
    let roll = try DiceEngine.roll(DiceExpression(count: 3, sides: 6, modifier: 0), seed: 9)
    #expect(roll.values.allSatisfy { (1...6).contains($0) })
}
