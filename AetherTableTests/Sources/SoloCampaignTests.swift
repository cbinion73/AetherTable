import AetherTableCore
@testable import AetherTable
import AIGM
import Foundation
import Persistence
import RulesPacks
import Testing

@Test func soloFullArcSurvivesReloadAndKeepsNotes() async throws {
    let store = InMemoryCampaignStore()
    var state = try SoloCampaign.create(name: "  Rowan  ")
    #expect(try SRD521CharacterProfile.from(campaign: state).name == "Rowan")
    #expect(state.world.locationID == "emberwake.old-bridge")
    var seed: UInt64 = 0
    while state.world.encounter?.status == .active && seed < 200 {
        state = try SoloCampaign.resolve(SoloCampaign.isAvailable(.attack, in: state) ? .attack : .enemyTurn, in: state, seed: seed)
        seed += 1
    }
    #expect(state.world.encounter?.status == .ended)
    if state.world.quest.stage == "recover" { state = try SoloCampaign.resolve(.recover, in: state, seed: 1) }
    #expect(state.world.quest.stage == "archive")
    state = try SoloCampaign.resolve(.archive("sera-memory"), in: state, seed: 4)
    #expect(state.world.locationID == "emberwake.vault")
    state = try SoloCampaign.resolve(.vault("reveal"), in: state, seed: 6)
    let recap = state.recap
    state = try SoloCampaign.addingNote("  Remember the debt.  ", to: state)
    #expect(state.recap == recap)
    try await store.save(state)
    #expect(try await store.load(id: state.id) == state)
    #expect(state.world.quest.stage == "complete")
    #expect(!SoloCampaign.isAvailable(.vault("break"), in: state))
    #expect(throws: SoloCampaignError.self) { try SoloCampaign.resolve(.attack, in: state, seed: 0) }
}

@Test func defeatRecoveryIsDurableAndActuallyHeals() throws {
    var state = try SoloCampaign.create(name: "Rowan")
    try state.apply(.init(campaignID: state.id, kind: .combatantDamaged, payload: ["combatantID": "player", "damage": "12"]))
    let encounter = try #require(state.world.encounter)
    let completion = try #require(LanternBelowEncounter.completionEvents(campaignID: state.id, encounter: encounter))
    for event in completion.events { try state.apply(event) }
    #expect(state.world.quest.stage == "recover")
    state = try SoloCampaign.resolve(.recover, in: state, seed: 1)
    #expect(SoloCampaign.hitPoints(in: state) == 12)
    #expect(state.world.encounter?.combatants.first(where: { $0.id == "player" })?.conditions.isEmpty == true)
    #expect(state.world.quest.stage == "archive")
    #expect(!SoloCampaign.isAvailable(.recover, in: state))
}

@Test func secondWindCapsHealsAndEnforcesTurnAndUsageLimits() throws {
    var state = try SoloCampaign.create(name: "Rowan")
    try state.apply(.init(campaignID: state.id, kind: .combatantDamaged, payload: ["combatantID": "player", "damage": "1"]))
    state = try SoloCampaign.resolve(.secondWind, in: state, seed: 5)
    #expect(SoloCampaign.hitPoints(in: state) == 12)
    #expect(SoloCampaign.secondWindUses(in: state) == 1)
    #expect(!SoloCampaign.isAvailable(.secondWind, in: state))
    #expect(SoloCampaign.isAvailable(.attack, in: state))
    try state.apply(.init(campaignID: state.id, kind: .turnStarted, payload: ["combatantID": "player", "round": "2"]))
    state = try SoloCampaign.resolve(.secondWind, in: state, seed: 6)
    try state.apply(.init(campaignID: state.id, kind: .turnStarted, payload: ["combatantID": "player", "round": "3"]))
    #expect(!SoloCampaign.isAvailable(.secondWind, in: state))
    #expect(SoloCampaign.secondWindUses(in: state) == 0)
    #expect(state.events.last(where: { $0.kind == .combatantHealed })?.payload["seed"] == "6")
}

@Test func campaignDiscoveryKeepsCorruptionAndOtherCampaigns() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try FileCampaignStore(directory: directory)
    let first = try SoloCampaign.create(name: "First")
    let second = try SoloCampaign.create(name: "Second")
    try await store.save(first); try await store.save(second)
    let broken = directory.appendingPathComponent("broken.json")
    try Data("broken".utf8).write(to: broken)
    let library = try await store.discover()
    #expect(library.campaigns.count == 2)
    #expect(library.unreadableFiles == ["broken.json"])
    #expect(try Data(contentsOf: broken) == Data("broken".utf8))
}

private actor FailingStore: CampaignStore {
    var state: CampaignState?
    var fail = false
    func load(id: CampaignID) async throws -> CampaignState? { state }
    func save(_ campaign: CampaignState) async throws {
        if fail { throw CocoaError(.fileWriteOutOfSpace) }
        state = campaign
    }
    func setFailure() { fail = true }
}
private struct UnavailableGM: GameMaster {
    func proposeIntent(from: String, campaign: CampaignState) async throws -> GMIntentProposal { throw GameMasterError.unavailable("test") }
    func narrate(resolved: CampaignEvent, campaign: CampaignState) async throws -> String { throw GameMasterError.unavailable("test") }
}
@MainActor @Test func failedSaveDoesNotPublishTurnOrLoseRecap() async throws {
    let store = FailingStore()
    let model = CampaignViewModel(store: store, gm: UnavailableGM())
    await model.start()
    #expect(await model.create(name: "Rowan"))
    let before = try #require(model.campaign)
    await store.setFailure()
    await model.perform(.attack, seed: 42)
    #expect(model.campaign == before)
    #expect(model.error != nil)
    #expect(!model.isResolving)
    #expect(try await store.load(id: before.id) == before)
}

@MainActor @Test func duplicateConcurrentAttackCommitsOnlyOnce() async throws {
    let model = CampaignViewModel(store: InMemoryCampaignStore(), gm: UnavailableGM())
    await model.start()
    #expect(await model.create(name: "Rowan"))
    async let first: Void = model.perform(.attack, seed: 42)
    async let second: Void = model.perform(.attack, seed: 42)
    _ = await (first, second)
    #expect(model.campaign?.events.filter { $0.kind == .actionResolved }.count == 1)
    #expect(model.campaign?.recap.contains("Apple Intelligence") == false)
}
