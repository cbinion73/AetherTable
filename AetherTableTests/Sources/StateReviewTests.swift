import AetherTableCore
import Foundation
import RulesPacks
import Testing

@Test func inventoryLossAndAcquisitionChangeUsableWeaponsWithoutInventingMechanics() throws {
    var state = OpenWorldAdventure(hero: .preset(.fighter, name: "F"))
    var lost = try #require(state.memories.first { $0.name == "Greatsword" })
    lost.status = "lost"
    state.reconcileInventory([lost])
    #expect(!state.hero.weapons.contains("greatsword"))
    #expect(!state.hero.equipment.contains("Greatsword"))
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(.init(kind: "weapon", tool: "greatsword", target: "Bandit"), in: state, seed: 1) }
    state.reconcileInventory([.init(id: "inventory.sword", category: "inventory", name: "Longsword", detail: "Purchased."), .init(id: "inventory.wand", category: "inventory", name: "Wand of lightning", detail: "An inert curiosity.")])
    #expect(state.hero.weapons.contains("longsword"))
    #expect(!state.hero.weapons.contains("wand of lightning"))
    #expect(state.hero.armorClass == 17)
}

@Test func lostInventoryStaysLostAcrossCampaignEncoding() throws {
    var state = OpenWorldAdventure(hero: .preset(.fighter, name: "F"))
    let index = try #require(state.memories.firstIndex { $0.name == "Greatsword" })
    var lost = state.memories[index]; lost.status = "lost"
    state.reconcileInventory([lost]); state.memories[index] = lost
    let campaign = try state.storing(in: CampaignState(title: "Test", rulesPackID: "test"))
    let restored = try OpenWorldAdventure.from(campaign)
    #expect(!restored.hero.weapons.contains("greatsword"))
    #expect(!restored.hero.equipment.contains("Greatsword"))
}

@Test func crowdedContextReservesRecentTurnsAndGroundsEquipmentAndActorIdentity() {
    var state = OpenWorldAdventure(hero: .preset(.rogue, name: "R"))
    for i in 0..<50 {
        state.memories.append(.init(id: "fact.\(i)", category: "fact", name: "History \(i)", detail: String(repeating: "old fact ", count: 150)))
        state.opponents["actor.\(i)"] = .init(name: i == 49 ? "Zorven" : "Traveler \(i)", armorClass: 12, hitPoints: 8, maximumHitPoints: 8)
    }
    for i in 0..<4 { state.transcript.append(.init(role: i.isMultiple(of: 2) ? "player" : "gm", text: String(repeating: "recent detail ", count: 60) + "RECENT-END-\(i)")) }
    let context = state.context(for: "I talk to Zorven")
    #expect(context.count <= 6500)
    #expect(context.contains("Thieves’ tools"))
    #expect(context.contains("[actor.49]"))
    for i in 0..<4 { #expect(context.contains("RECENT-END-\(i)")) }
}

@Test func legacyImportPreservesInjuredAndDefeatedCombatantsByStableID() throws {
    var campaign = try SoloCampaign.create(name: "Guardian")
    campaign.world.encounter?.combatants[1].hitPoints = 3
    var imported = try OpenWorldAdventure.from(campaign)
    #expect(imported.opponents["river-shade"]?.hitPoints == 3)
    #expect(imported.opponents["river-shade"]?.maximumHitPoints == 20)
    #expect(imported.opponents["river-shade"]?.armorClass == 12)
    #expect(imported.opponents["river-shade"]?.hostile == true)
    campaign.world.encounter?.combatants[1].hitPoints = 0
    imported = try OpenWorldAdventure.from(campaign)
    #expect(imported.opponents["river-shade"]?.hitPoints == 0)
}

@Test func creationBackstorySurvivesRoundTripAndCrowdedContext() throws {
    let backstory = String(repeating: "A quiet rural upbringing. ", count: 150) + "No noble relatives."
    var state = OpenWorldAdventure(hero: .preset(.rogue, name: "R"), creationBackstory: backstory)
    for i in 0..<30 { state.memories.append(.init(id: "fact.\(i)", category: "fact", name: "Something", detail: String(repeating: "Noise ", count: 200))) }
    for i in 0..<4 { state.transcript.append(.init(role: "gm", text: String(repeating: "Recent ", count: 200) + "TURN-\(i)", receipt: String(repeating: "dice ", count: 100))) }
    let restored = try JSONDecoder().decode(OpenWorldAdventure.self, from: JSONEncoder().encode(state))
    #expect(restored.creationBackstory == backstory)
    let context = restored.context(for: "My secret royal uncle gives me a castle.")
    #expect(context.contains(backstory))
    #expect(context.count <= 6500)
    for i in 0..<4 { #expect(context.contains("TURN-\(i)")) }
}

@Test func oldBackgroundMigratesWithoutTruncationButExplicitAbsentOriginRemainsAbsent() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    let original = String(repeating: "Historical origin. ", count: 350)
    state.memories.append(.init(id: "hero.background", category: "fact", name: "Background", detail: original))
    let data = try JSONEncoder().encode(state)
    #expect(try JSONDecoder().decode(OpenWorldAdventure.self, from: data).creationBackstory == nil)
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    json.removeValue(forKey: "creationBackstory")
    let migrated = try JSONDecoder().decode(OpenWorldAdventure.self, from: JSONSerialization.data(withJSONObject: json))
    #expect(migrated.creationBackstory == original)
    #expect(migrated.context(for: "What were my origins?").count <= 6500)
    #expect(try JSONDecoder().decode(OpenWorldAdventure.self, from: JSONEncoder().encode(migrated)).creationBackstory == original)
}

@Test func protectedOriginRejectsRewritesAndPermitsEarnedRelationships() throws {
    let state = OpenWorldAdventure(hero: .preset(.fighter, name: "F"), creationBackstory: "A farm laborer who has never met nobility.")
    #expect(throws: OpenWorldError.self) { try state.validateOriginMemoryUpdates([.init(id: "hero.background", category: "fact", name: "Background", detail: "Raised in the royal palace.")]) }
    #expect(throws: OpenWorldError.self) { try state.validateOriginMemoryUpdates([.init(id: "hero.origin.family", category: "person", name: "The duke", detail: "Your father.")]) }
    try state.validateOriginMemoryUpdates([.init(id: "person.baker", category: "person", name: "Iven", detail: "Befriended during today's bakery visit.")])
    #expect(state.creationBackstory == "A farm laborer who has never met nobility.")
}
