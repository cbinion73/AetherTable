import AetherTableCore
import AIGM
import Foundation
import Observation
import Persistence
import RulesPacks

@MainActor @Observable
final class CampaignViewModel {
    private(set) var campaigns: [CampaignState] = []
    private(set) var campaign: CampaignState?
    private(set) var isResolving = false
    private(set) var loaded = false
    var error: String?
    private(set) var unreadableFiles: [String] = []
    private(set) var aiStatus = "Authored narration · available offline"
    private(set) var aiNarration: String?
    private var store: (any CampaignStore)?
    private let gm: any GameMaster
    private var narrationTask: Task<Void, Never>?
    private let dungeonMaster: any DungeonMaster
    var draft = "" {
        didSet { if let id = campaign?.id.rawValue.uuidString { UserDefaults.standard.set(draft, forKey: "AetherTable.draft.\(id)") } }
    }
    private(set) var turnStatus = ""
    private(set) var returnRecap: String?
    private(set) var isShowingReturnRecap = false
    private(set) var isSaving = false
    private var turnTask: Task<Void, Never>?
    private var isTurnActive = false
    private var turnToken = UUID()
    private var pending: (campaignID: CampaignID, text: String, resolution: WorldResolution, candidate: CampaignState?)?
    private var pendingBase: CampaignState?
    var adventure: OpenWorldAdventure? { campaign.flatMap { try? OpenWorldAdventure.from($0) } }
    init(store: (any CampaignStore)? = nil, gm: any GameMaster = FoundationModelsGM(), dungeonMaster: any DungeonMaster = AppleDungeonMaster()) { self.store = store; self.gm = gm; self.dungeonMaster = dungeonMaster }
    func start() async {
        guard !isResolving else { return }
        isResolving = true
        defer { isResolving = false; loaded = true }
        do {
            if store == nil { store = try FileCampaignStore() }
            guard let store else { return }
            let library = try await store.discover()
            var readable: [CampaignState] = []
            var unreadable = library.unreadableFiles
            for candidate in library.campaigns {
                do { _ = try OpenWorldAdventure.from(candidate); readable.append(candidate) }
                catch { unreadable.append("\(candidate.id.rawValue.uuidString).json") }
            }
            campaigns = readable; unreadableFiles = unreadable; error = nil
        } catch { self.error = "Campaign storage could not be opened. Your files have been preserved. Check device storage, then retry. \(error.localizedDescription)" }
    }
    func select(_ state: CampaignState) {
        guard !isResolving else { return }
        do { _ = try OpenWorldAdventure.from(state) }
        catch { self.error = "This adventure could not be read. Its saved file has been preserved. \(error.localizedDescription)"; return }
        narrationTask?.cancel(); campaign = state; draft = UserDefaults.standard.string(forKey: "AetherTable.draft.\(state.id.rawValue.uuidString)") ?? ""; pending = nil; aiNarration = nil; aiStatus = "Apple Intelligence Dungeon Master"
        if let adventure, Date.now.timeIntervalSince(adventure.lastPlayedAt) > 86_400 { returnRecap = adventure.returnRecap; isShowingReturnRecap = false }
    }
    func leave() { guard !isResolving else { return }; narrationTask?.cancel(); campaign = nil; draft = ""; pending = nil; aiNarration = nil; returnRecap = nil; isShowingReturnRecap = false }
    @discardableResult func createAdventure(name: String, characterClass: AdventurerClass, backstory: String = "", opening: AdventureOpening = .default) async -> Bool {
        guard !isResolving, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        isResolving = true
        defer { isResolving = false }
        do {
            let history = backstory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard history.count <= 4000 else { throw OpenWorldError.invalidPlan("Keep your creation backstory within 4,000 characters. It is saved exactly as written.") }
            guard opening.isValid else { throw OpenWorldError.invalidPlan("Complete all opening-story fields before starting the campaign.") }
            let state = OpenWorldAdventure(hero: .preset(characterClass, name: name), creationBackstory: history.isEmpty ? nil : history, opening: opening)
            let campaign = CampaignState(title: "\(state.hero.name)’s Adventure", rulesPackID: SRD521RulesPack.descriptor.id)
            try await commit(state.storing(in: campaign)); draft = ""; pending = nil; return true
        } catch { report(error); return false }
    }
    @discardableResult func createAdventure(character: CharacterCreationDraft, backstory: String, opening: AdventureOpening = .default) async -> Bool {
        guard !isResolving else { return false }
        isResolving = true
        defer { isResolving = false }
        do {
            let hero = try character.build()
            let history = backstory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard history.count <= 4000 else { throw OpenWorldError.invalidPlan("Keep your creation backstory within 4,000 characters.") }
            guard opening.isValid else { throw OpenWorldError.invalidPlan("Complete all opening-story fields before starting the campaign.") }
            let world = OpenWorldAdventure(hero: hero, creationBackstory: history.isEmpty ? nil : history, opening: opening)
            let newCampaign = CampaignState(title: "\(hero.name)’s Adventure", rulesPackID: SRD521RulesPack.descriptor.id)
            try await commit(world.storing(in: newCampaign))
            draft = ""; pending = nil; pendingBase = nil
            return true
        } catch { report(error); return false }
    }
    func resumeAfterAbsence() async {
        guard !isResolving, let campaign, var world = try? OpenWorldAdventure.from(campaign) else { return }
        returnRecap = nil; isShowingReturnRecap = false
        world.lastPlayedAt = .now
        do { try await commit(world.storing(in: campaign)) }
        catch { report(error) }
    }
    func showReturnRecap() { guard returnRecap != nil else { return }; isShowingReturnRecap = true }
    func send(opening: Bool = false) {
        guard !isResolving else { return }
        turnTask = Task { await submit(opening: opening) }
    }
    func cancelTurn() {
        guard isTurnActive, !isSaving else { return }
        turnTask?.cancel(); turnToken = UUID(); isTurnActive = false; isResolving = false; turnStatus = "Turn cancelled. Your draft is unchanged."
    }
    func submit(opening: Bool = false) async {
        guard !Task.isCancelled, !isResolving, let original = campaign else { return }
        let text = opening ? "Begin my adventure." : draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 3000 else { error = "Write an action of 3,000 characters or fewer."; return }
        let token = UUID(); turnToken = token; isTurnActive = true; isResolving = true; error = nil
        defer { if token == turnToken { isTurnActive = false; isResolving = false; turnStatus = "" } }
        do {
            let state = try OpenWorldAdventure.from(original)
            if pending?.campaignID != original.id || pending?.text != text || pendingBase != original { pending = nil; pendingBase = nil }
            if pending == nil {
                turnStatus = "The Dungeon Master is considering your action…"
                let plan = try await dungeonMaster.plan(playerText: text, adventure: state)
                guard token == turnToken, !Task.isCancelled else { return }
                let resolution = try OpenWorldEngine.resolve(plan, in: state, seed: .random(in: .min ... .max))
                pending = (original.id, text, resolution, nil)
                pendingBase = original
            }
            guard let prepared = pending else { return }
            var candidate = prepared.candidate
            if candidate == nil {
                turnStatus = "Your story is taking shape…"
                let story = try await dungeonMaster.tell(playerText: text, resolution: prepared.resolution)
                guard token == turnToken, !Task.isCancelled else { return }
                let updated = try AdventureTurn.finish(playerText: text, resolution: prepared.resolution, story: story)
                candidate = try updated.storing(in: original)
                pending?.candidate = candidate
            }
            guard let candidate, token == turnToken, !Task.isCancelled else { return }
            turnStatus = "Saving your story…"
            try await commit(candidate)
            pending = nil; pendingBase = nil; draft = ""; aiStatus = "Apple Intelligence Dungeon Master"
        } catch {
            guard token == turnToken, !Task.isCancelled else { return }
            self.error = "\(error.localizedDescription)\nYour saved story and draft are unchanged. Retry to continue the same turn."
        }
    }
    @discardableResult func create(name: String) async -> Bool {
        guard !isResolving else { return false }
        isResolving = true
        defer { isResolving = false }
        do { try await commit(SoloCampaign.create(name: name)); return true }
        catch { report(error); return false }
    }
    func perform(_ action: SoloAction, seed: UInt64 = .random(in: .min ... .max)) async {
        guard !isResolving, let campaign, SoloCampaign.isAvailable(action, in: campaign) else { return }
        isResolving = true
        defer { isResolving = false }
        do {
            let updated = try SoloCampaign.resolve(action, in: campaign, seed: seed)
            try await commit(updated)
            if let event = updated.events.last(where: { $0.kind == .actionResolved }), action != .recover && action != .secondWind {
                aiStatus = "Apple Intelligence is adding atmosphere…"
                narrationTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        let text = try await gm.narrate(resolved: event, campaign: updated)
                        guard !Task.isCancelled, self.campaign?.id == updated.id, self.campaign?.events.last?.id == updated.events.last?.id else { return }
                        aiNarration = text; aiStatus = "Apple Intelligence · optional narration"
                    } catch {
                        guard !Task.isCancelled, self.campaign?.id == updated.id, self.campaign?.events.last?.id == updated.events.last?.id else { return }
                        aiStatus = "Apple Intelligence unavailable · authored story remains ready"
                    }
                }
            }
        } catch { report(error) }
    }
    @discardableResult func saveNote(_ text: String) async -> Bool {
        guard !isResolving, let campaign else { return false }
        isResolving = true
        defer { isResolving = false }
        do { try await commit(SoloCampaign.addingNote(text, to: campaign)); return true }
        catch { report(error); return false }
    }
    @discardableResult func saveWorldNote(_ text: String) async -> Bool {
        guard !isResolving, let campaign else { return false }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        isResolving = true
        defer { isResolving = false }
        do {
            var world = try OpenWorldAdventure.from(campaign)
            world.transcript.append(.init(role: "note", text: trimmed))
            world.memories.append(.init(id: "note.\(UUID().uuidString)", category: "fact", name: "Player note", detail: trimmed))
            try await commit(world.storing(in: campaign)); return true
        } catch { report(error); return false }
    }
    private func commit(_ state: CampaignState) async throws {
        guard let store else { throw GameMasterError.unavailable("Campaign storage is not ready. Return to the library and retry.") }
        isSaving = true
        defer { isSaving = false }
        try await store.save(state)
        narrationTask?.cancel()
        campaign = state
        campaigns.removeAll { $0.id == state.id }; campaigns.insert(state, at: 0)
        aiNarration = nil; aiStatus = "Authored narration · available offline"; error = nil
    }
    private func report(_ failure: Error) { error = "The change could not be saved. Your previous progress is unchanged. Check device storage and try again. \(failure.localizedDescription)" }
}
