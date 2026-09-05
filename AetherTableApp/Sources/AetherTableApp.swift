import AetherTableCore
import AIGM
import DiceEngine
import Persistence
import RulesPacks
import SwiftUI

@main
struct AetherTableApp: App { var body: some Scene { WindowGroup { CampaignHomeView() } } }

struct CampaignHomeView: View {
    @State private var model = CampaignViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("AETHERTABLE").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.tint)
                            Text(model.hasCampaign ? "The Lantern Below" : "Your next story is waiting")
                                .font(.largeTitle.bold())
                        }

                        if model.hasCampaign {
                            StoryCard(title: model.sceneTitle, body: model.scenePrompt)
                            VStack(alignment: .leading, spacing: 10) {
                                Text("THE GM SAYS").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                                Text(model.gmNarration).font(.title3).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(20)
                            .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                            if !model.lastRoll.isEmpty {
                                Label(model.lastRoll, systemImage: "dice.fill")
                                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text("WHAT DO YOU DO?").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(.secondary)
                                if model.canResolveSRDAttack {
                                    StoryAction(title: "Strike with your longsword", detail: "Roll to drive the River Shade back.") { Task { await model.resolveSRDAttack() } }
                                }
                                if model.canResolveRiverShadeTurn {
                                    StoryAction(title: "Continue", detail: "Let the River Shade answer your move.") { Task { await model.resolveRiverShadeTurn() } }
                                }
                                if model.canResolveArchiveChoice {
                                    ForEach(LanternBelowFloodedArchive.choices) { choice in
                                        StoryAction(title: choice.title, detail: choice.prompt) { Task { await model.resolveArchive(choiceID: choice.id) } }
                                    }
                                }
                                if model.canResolveVaultChoice {
                                    ForEach(LanternBelowVault.choices) { choice in
                                        StoryAction(title: choice.title, detail: choice.prompt) { Task { await model.resolveVault(choiceID: choice.id) } }
                                    }
                                }
                            }
                            if model.isResolving { ProgressView("The story is moving…").frame(maxWidth: .infinity).padding(.top, 4) }
                        } else {
                            StoryCard(title: "The Lantern Below", body: "Emberwake’s river has begun to flow upstream. Beneath the old bridge, something waits in the dark—and it knows your name.")
                            Text("A short, persistent fantasy campaign. Open it, make a choice, and come back whenever you have time.")
                                .font(.title3).foregroundStyle(.secondary)
                            Button("Begin the story") { Task { await model.startSRDQuickstart() } }
                                .buttonStyle(.borderedProminent).controlSize(.large).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 620, alignment: .leading)
                }
            }
            .task { await model.start() }
        }
    }
}

private struct StoryCard: View {
    let title: String
    let bodyText: String
    init(title: String, body: String) { self.title = title; self.bodyText = body }
    var bodyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title2.bold())
            Text(bodyText).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
    var body: some View { bodyView }
}

private struct StoryAction: View {
    let title: String
    let detail: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }
        .buttonStyle(.plain)
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

@MainActor @Observable
final class CampaignViewModel {
    var hasCampaign = false
    var sceneTitle = "The Lantern Below"
    var scenePrompt = "Emberwake’s river has begun to flow upstream."
    var gmNarration = "The river is quiet for now."
    var lastRoll = ""
    var isResolving = false
    var canResolveSRDAttack = false
    var canResolveRiverShadeTurn = false
    var canResolveArchiveChoice = false
    var canResolveVaultChoice = false

    private var campaign: CampaignState?
    private let gm = FoundationModelsGM()
    private let store: any CampaignStore
    private let lastCampaignIDKey = "AetherTable.lastCampaignID"

    init() { store = (try? FileCampaignStore()) ?? InMemoryCampaignStore() }

    func start() async {
        guard let rawID = UserDefaults.standard.string(forKey: lastCampaignIDKey), let uuid = UUID(uuidString: rawID), let restored = try? await store.load(id: .init(rawValue: uuid)) else { return }
        campaign = restored
        hasCampaign = true
        updatePresentation(from: restored)
        gmNarration = restored.recap
    }

    func startSRDQuickstart() async {
        isResolving = true
        defer { isResolving = false }
        do {
            let profile = try SRD521QuickstartCharacter.guardian()
            var newCampaign = CampaignState(title: "The Lantern Below", rulesPackID: SRD521RulesPack.descriptor.id, recap: "A river shade blocks the bridge beneath Emberwake.")
            try newCampaign.apply(profile.stateEvent(campaignID: newCampaign.id))
            let guardian = EncounterCombatant(id: "player", name: profile.name, team: .player, initiative: 14, maximumHitPoints: profile.maximumHitPoints, armorClass: profile.armorClass)
            let shade = EncounterCombatant(id: "river-shade", name: "River Shade", team: .enemy, initiative: 9, maximumHitPoints: 20, armorClass: 12)
            for event in SRD521EncounterEngine.startEvents(campaignID: newCampaign.id, encounterID: "emberwake.river-shade", title: "Dark Beneath the Bridge", combatants: [guardian, shade]) {
                try newCampaign.apply(event)
            }
            campaign = newCampaign
            hasCampaign = true
            lastRoll = ""
            gmNarration = "The water beneath Old Bridge stirs. A pale shape lifts itself from the current."
            updatePresentation(from: newCampaign)
            try await persist(newCampaign)
        } catch {
            gmNarration = "The story could not begin. Please try again."
        }
    }

    func resolveSRDAttack() async {
        guard var campaign, let encounter = campaign.world.encounter else { return }
        isResolving = true
        defer { isResolving = false }
        do {
            let profile = try SRD521CharacterProfile.from(campaign: campaign)
            let request = try profile.attackRequest(attackID: "longsword", targetID: "river-shade")
            let seed = UInt64.random(in: .min ... .max)
            let resolution = try SRD521EncounterEngine.resolveAttack(campaignID: campaign.id, in: encounter, request: request, seed: seed)
            for event in resolution.events { try campaign.apply(event) }
            let completion = try applyEncounterCompletion(to: &campaign)
            if completion == nil, let next = try? SRD521EncounterEngine.nextTurnEvent(campaignID: campaign.id, encounter: campaign.world.encounter!) { try campaign.apply(next) }
            self.campaign = campaign
            let targetHP = campaign.world.encounter?.combatants.first(where: { $0.id == "river-shade" })?.hitPoints ?? 0
            lastRoll = resolution.attack.outcome == .criticalHit ? "Critical hit — " + String(resolution.damage) + " damage." : "River Shade: " + String(targetHP) + " vitality remaining."
            updatePresentation(from: campaign)
            try await persist(campaign)
            if let event = resolution.events.first(where: { $0.kind == .actionResolved }) { await refreshGMNarration(for: event, in: campaign) }
        } catch {
            gmNarration = "The strike could not be resolved. Try again."
        }
    }

    func resolveRiverShadeTurn() async {
        guard var campaign, let encounter = campaign.world.encounter else { return }
        isResolving = true
        defer { isResolving = false }
        do {
            let seed = UInt64.random(in: .min ... .max)
            let resolution = try SRD521EncounterEngine.resolveAttack(campaignID: campaign.id, in: encounter, request: LanternBelowEncounter.riverShadeAttack(), seed: seed)
            for event in resolution.events { try campaign.apply(event) }
            let completion = try applyEncounterCompletion(to: &campaign)
            if completion == nil, let next = try? SRD521EncounterEngine.nextTurnEvent(campaignID: campaign.id, encounter: campaign.world.encounter!) { try campaign.apply(next) }
            self.campaign = campaign
            let playerHP = campaign.world.encounter?.combatants.first(where: { $0.id == LanternBelowEncounter.playerID })?.hitPoints ?? 0
            lastRoll = playerHP > 0 ? "You have " + String(playerHP) + " vitality remaining." : "The current pulls you under."
            updatePresentation(from: campaign)
            try await persist(campaign)
            if let event = resolution.events.first(where: { $0.kind == .actionResolved }) { await refreshGMNarration(for: event, in: campaign) }
        } catch {
            gmNarration = "The river’s answer could not be resolved. Try again."
        }
    }

    func resolveArchive(choiceID: String) async {
        guard var campaign else { return }
        isResolving = true
        defer { isResolving = false }
        do {
            let profile = try SRD521CharacterProfile.from(campaign: campaign)
            let seed = UInt64.random(in: .min ... .max)
            let die = try DiceEngine.roll(.init(count: 1, sides: 20), seed: seed).values[0]
            let resolution = try LanternBelowFloodedArchive.resolve(campaignID: campaign.id, profile: profile, choiceID: choiceID, die: die)
            try campaign.apply(resolution.event)
            for event in try LanternBelowFloodedArchive.consequenceEvents(campaignID: campaign.id, choiceID: choiceID, result: resolution.result) { try campaign.apply(event) }
            self.campaign = campaign
            lastRoll = resolution.result.outcome == .success ? "The archive yields." : "The archive yields—but the alarm is raised."
            updatePresentation(from: campaign)
            try await persist(campaign)
            await refreshGMNarration(for: resolution.event, in: campaign)
        } catch {
            gmNarration = "The archive will not answer yet. Try again."
        }
    }

    func resolveVault(choiceID: String) async {
        guard var campaign else { return }
        isResolving = true
        defer { isResolving = false }
        do {
            let profile = try SRD521CharacterProfile.from(campaign: campaign)
            let seed = UInt64.random(in: .min ... .max)
            let die = try DiceEngine.roll(.init(count: 1, sides: 20), seed: seed).values[0]
            let resolution = try LanternBelowVault.resolve(campaignID: campaign.id, campaign: campaign, profile: profile, choiceID: choiceID, die: die)
            try campaign.apply(resolution.event)
            for event in try LanternBelowVault.consequenceEvents(campaignID: campaign.id, choiceID: choiceID, result: resolution.result) { try campaign.apply(event) }
            self.campaign = campaign
            lastRoll = "Your choice has changed Emberwake."
            updatePresentation(from: campaign)
            try await persist(campaign)
            await refreshGMNarration(for: resolution.event, in: campaign)
        } catch {
            gmNarration = "The vault cannot answer that choice yet."
        }
    }

    private func applyEncounterCompletion(to campaign: inout CampaignState) throws -> LanternBelowEncounter.Completion? {
        guard let encounter = campaign.world.encounter, let result = LanternBelowEncounter.completionEvents(campaignID: campaign.id, encounter: encounter) else { return nil }
        for event in result.events { try campaign.apply(event) }
        return result.completion
    }

    private func persist(_ campaign: CampaignState) async throws {
        try await store.save(campaign)
        UserDefaults.standard.set(campaign.id.rawValue.uuidString, forKey: lastCampaignIDKey)
    }

    private func updatePresentation(from campaign: CampaignState) {
        canResolveSRDAttack = false
        canResolveRiverShadeTurn = false
        canResolveArchiveChoice = false
        canResolveVaultChoice = false

        if let encounter = campaign.world.encounter, encounter.status == .active {
            sceneTitle = "Dark Beneath the Bridge"
            scenePrompt = "The River Shade bars the path beneath Old Bridge. The current presses close, waiting for your next move."
            canResolveSRDAttack = encounter.activeCombatantID == LanternBelowEncounter.playerID
            canResolveRiverShadeTurn = encounter.activeCombatantID == LanternBelowEncounter.riverShadeID
            return
        }

        switch campaign.world.quest.stage {
        case "archive":
            sceneTitle = "The Flooded Archive"
            scenePrompt = "The brass tide-key opens a lock beneath the waterline. Emberwake buried something here—and the water remembers."
            canResolveArchiveChoice = true
        case "vault":
            sceneTitle = "The Lantern Vault"
            scenePrompt = "Nym-of-the-Reed waits at the threshold: not a monster, not a saint, and not free. What Emberwake owes is now yours to decide."
            canResolveVaultChoice = true
        case "complete":
            sceneTitle = "A Choice Remembered"
            scenePrompt = campaign.world.quest.objective
        default:
            sceneTitle = "The Lantern Below"
            scenePrompt = campaign.world.quest.objective
        }
    }

    private func refreshGMNarration(for event: CampaignEvent, in campaign: CampaignState) async {
        do {
            gmNarration = try await gm.narrate(resolved: event, campaign: campaign)
        } catch {
            gmNarration = "The outcome is saved and ready. Apple Intelligence narration is unavailable on this device."
        }
    }
}
