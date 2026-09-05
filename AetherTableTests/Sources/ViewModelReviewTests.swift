import AetherTableCore
@testable import AetherTable
import Foundation
import Persistence
import RulesPacks
import Testing

@MainActor @Test func createdCharacterChoicesAndLockedBackstorySurviveReopening() async throws {
    let store = InMemoryCampaignStore()
    let model = CampaignViewModel(store: store)
    await model.start()
    var character = CharacterCreationDraft.suggested(for: .fighter, name: "Creation QA")
    character.method = .pointBuy
    let origin = "My mother serves as high priestess of the city temple. My father is a noble."
    #expect(await model.createAdventure(character: character, backstory: origin))
    let saved = try #require(model.campaign)
    let reopened = CampaignViewModel(store: store)
    await reopened.start()
    reopened.select(try #require(reopened.campaigns.first))
    #expect(reopened.campaign?.id == saved.id)
    #expect(reopened.adventure?.hero.creation == character)
    #expect(reopened.adventure?.creationBackstory == origin)
    #expect(reopened.adventure?.hero.scores == character.finalScores)
}

@MainActor @Test func shiningRoadPlaytestCreatesABrightOpenStarterWithTestEquipment() async throws {
    let model = CampaignViewModel(store: InMemoryCampaignStore())
    await model.start()
    #expect(await model.createShiningRoadPlaytest())
    let world = try #require(model.adventure)
    #expect(world.location == "The Sunspire Festival, on the shining road to Larkhaven")
    #expect(world.hero.characterClass == .cleric)
    #expect(world.hero.equipment.contains("Festival map") && world.hero.equipment.contains("Healer’s kit"))
    #expect(world.memories.contains { $0.id == "quest.shining.road" })
}

@MainActor @Test func invalidCharacterAllocationCannotCreateASave() async throws {
    let store = InMemoryCampaignStore()
    let model = CampaignViewModel(store: store)
    await model.start()
    var character = CharacterCreationDraft.suggested(for: .fighter, name: "Invalid")
    character.method = .pointBuy
    for ability in CharacterCreationDraft.abilities { character.baseScores[ability] = 15 }
    #expect(!(await model.createAdventure(character: character, backstory: "")))
    #expect(model.campaign == nil)
    #expect(try await store.discover().campaigns.isEmpty)
}

@Test func openingBriefingSurvivesEncodingAndGroundsGMContext() throws {
    let opening = AdventureOpening(place: "The Lantern Quay", activity: "guarding a midnight cargo", companions: "Captain Maelin and her nervous crew", reason: "to repay a debt to Maelin", premise: "A sealed crate begins answering questions in a child's voice.")
    let state = OpenWorldAdventure(hero: .preset(.rogue, name: "Mara"), opening: opening)
    let restored = try JSONDecoder().decode(OpenWorldAdventure.self, from: JSONEncoder().encode(state))
    #expect(restored.opening == opening)
    #expect(restored.location == "The Lantern Quay")
    #expect(restored.context(for: "I inspect the crate").contains("guarding a midnight cargo"))
    #expect(restored.memories.contains { $0.id == "opening.premise" && $0.detail.contains("child's voice") })
}

@MainActor @Test func returningAfterADayOffersRecapUntilPlayerResumes() async throws {
    let store = InMemoryCampaignStore()
    let model = CampaignViewModel(store: store)
    await model.start()
    #expect(await model.createAdventure(name: "Return QA", characterClass: .cleric))
    var campaign = try #require(model.campaign)
    var world = try OpenWorldAdventure.from(campaign)
    world.lastPlayedAt = Date.now.addingTimeInterval(-86_401)
    campaign.world.packState[OpenWorldAdventure.key] = String(decoding: try JSONEncoder().encode(world), as: UTF8.self)
    try await store.save(campaign)
    let reopened = CampaignViewModel(store: store)
    await reopened.start()
    reopened.select(try #require(reopened.campaigns.first))
    #expect(reopened.returnRecap?.contains("Return QA") == true)
    await reopened.resumeAfterAbsence()
    #expect(reopened.returnRecap == nil)
}

@MainActor @Test func selectingAnotherCurrentCampaignClearsAStaleReturnPrompt() async throws {
    let store = InMemoryCampaignStore(), model = CampaignViewModel(store: store)
    await model.start()
    #expect(await model.createAdventure(name: "Old", characterClass: .fighter))
    var oldCampaign = try #require(model.campaign), oldWorld = try OpenWorldAdventure.from(oldCampaign)
    oldWorld.lastPlayedAt = Date.now.addingTimeInterval(-86_401)
    oldCampaign.world.packState[OpenWorldAdventure.key] = String(decoding: try JSONEncoder().encode(oldWorld), as: UTF8.self)
    try await store.save(oldCampaign)
    #expect(await model.createAdventure(name: "Current", characterClass: .rogue))
    let currentCampaign = try #require(model.campaign)
    model.select(oldCampaign)
    #expect(model.returnRecap != nil)
    model.select(currentCampaign)
    #expect(model.returnRecap == nil && !model.isShowingReturnRecap)
}

@MainActor @Test func libraryRejectsMalformedEmbeddedAdventureWithoutChangingSavedData() async throws {
    let store = InMemoryCampaignStore()
    var corrupt = CampaignState(title: "Damaged", rulesPackID: SRD521RulesPack.descriptor.id)
    corrupt.world.packState[OpenWorldAdventure.key] = "{broken"
    let valid = try OpenWorldAdventure(hero: .preset(.fighter, name: "Valid")).storing(in: CampaignState(title: "Valid", rulesPackID: SRD521RulesPack.descriptor.id))
    try await store.save(corrupt)
    try await store.save(valid)
    let model = CampaignViewModel(store: store)
    await model.start()
    #expect(model.campaigns.map(\.id) == [valid.id])
    #expect(model.unreadableFiles == ["\(corrupt.id.rawValue.uuidString).json"])
    #expect(try await store.load(id: corrupt.id) == corrupt)
    model.select(valid)
    model.select(corrupt)
    #expect(model.campaign?.id == valid.id)
    #expect(model.error?.contains("could not be read") == true)
}

private actor SuspendedReviewStore: CampaignStore {
    private var states: [CampaignID: CampaignState] = [:]
    private var suspendNext = false
    private var resumeSave: CheckedContinuation<Void, Never>?
    private var waitingForSave: CheckedContinuation<Void, Never>?
    func load(id: CampaignID) async throws -> CampaignState? { states[id] }
    func discover() async throws -> CampaignLibrary { .init(campaigns: Array(states.values)) }
    func suspendNextSave() { suspendNext = true }
    func waitUntilSaving() async {
        if resumeSave != nil { return }
        await withCheckedContinuation { waitingForSave = $0 }
    }
    func releaseSave() { resumeSave?.resume(); resumeSave = nil }
    func save(_ campaign: CampaignState) async throws {
        if suspendNext {
            suspendNext = false
            await withCheckedContinuation { continuation in
                resumeSave = continuation
                waitingForSave?.resume(); waitingForSave = nil
            }
        }
        states[campaign.id] = campaign
    }
}

@MainActor @Test func cancellingDuringNoteSaveCannotUnlockSelectionOrLoseNote() async throws {
    let store = SuspendedReviewStore()
    let model = CampaignViewModel(store: store)
    await model.start()
    #expect(await model.createAdventure(name: "First", characterClass: .fighter))
    let first = try #require(model.campaign)
    #expect(await model.createAdventure(name: "Second", characterClass: .wizard))
    let second = try #require(model.campaign)
    model.select(first)
    await store.suspendNextSave()
    let saving = Task { await model.saveWorldNote("A promise worth keeping.") }
    await store.waitUntilSaving()
    #expect(model.isSaving && model.isResolving)
    model.cancelTurn()
    model.select(second)
    model.leave()
    #expect(model.isSaving && model.isResolving)
    #expect(model.campaign?.id == first.id)
    await store.releaseSave()
    #expect(await saving.value)
    #expect(!model.isSaving && !model.isResolving)
    #expect(model.adventure?.transcript.last?.text == "A promise worth keeping.")
    model.select(second)
    #expect(model.campaign?.id == second.id)
    let persisted = try #require(try await store.load(id: first.id))
    #expect(try OpenWorldAdventure.from(persisted).transcript.last?.text == "A promise worth keeping.")
}
