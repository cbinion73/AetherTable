import AetherTableCore
import AIGM
import DiceEngine
import Persistence
import RulesEngine
import RulesPacks
import SwiftUI

@main
struct AetherTableApp: App { var body: some Scene { WindowGroup { CampaignHomeView() } } }

struct CampaignHomeView: View {
    @State private var model = CampaignViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("One platform. Many worlds.") {
                    Text("AetherTable keeps the campaign truth in the engine. The AI Game Master brings it to life.")
                }
                Section("Rules Pack") {
                    Picker("Prototype", selection: $model.selectedPackID) {
                        ForEach(BuiltInRulesPacks.all, id: \.descriptor.id) { pack in
                            Text(pack.descriptor.displayName).tag(pack.descriptor.id)
                        }
                    }
                    let pack = BuiltInRulesPacks.all.first { $0.descriptor.id == model.selectedPackID }!
                    Text("\(pack.descriptor.mechanicFamily) • \(pack.descriptor.actionVerbs.joined(separator: ", "))")
                        .foregroundStyle(.secondary)
                }
                Section("Deterministic Dice") {
                    Text(model.resultText).monospacedDigit()
                    TextField("What do you do?", text: $model.playerText, axis: .vertical)
                    Button(model.isResolving ? "Resolving…" : "Resolve action") { Task { await model.resolveAction() } }
                        .disabled(model.playerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isResolving)
                }
                Section("Campaign Journal") { Text(model.recap) }
                Section("SRD 5.2.1 Encounter Preview") {
                    Text(model.srdSummary).foregroundStyle(.secondary)
                    Button("Create level-one guardian") { Task { await model.startSRDQuickstart() } }
                    Button("Roll guardian attack") { Task { await model.resolveSRDAttack() } }
                        .disabled(!model.canResolveSRDAttack || model.isResolving)
                    Button("Resolve River Shade turn") { Task { await model.resolveRiverShadeTurn() } }
                        .disabled(!model.canResolveRiverShadeTurn || model.isResolving)
                }
                Section("Status") { Text(model.statusText).foregroundStyle(.secondary) }
            }
            .navigationTitle("AetherTable")
            .task { await model.start() }
        }
    }
}

@MainActor @Observable
final class CampaignViewModel {
    var selectedPackID: RulesPackID = BuiltInRulesPacks.all[0].descriptor.id
    var playerText = "I investigate the strange signal."
    var resultText = "Awaiting an action"
    var recap = "Loading campaign…"
    var statusText = "Local solo campaign"
    var isResolving = false
    var srdSummary = "Create a source-cited level-one character and enter a persistent encounter."
    var canResolveSRDAttack = false
    var canResolveRiverShadeTurn = false

    private var campaign: CampaignState?
    private let rules = RulesEngine()
    private let gm = FoundationModelsGM()
    private let store: any CampaignStore

    init() { store = (try? FileCampaignStore()) ?? InMemoryCampaignStore() }

    func start() async {
        let newCampaign = CampaignState(title: "The First Thread", rulesPackID: selectedPackID, recap: "A strange signal reaches your party. What do you do?")
        campaign = newCampaign
        recap = newCampaign.recap
        try? await store.save(newCampaign)
    }

    func resolveAction() async {
        guard var campaign, let pack = BuiltInRulesPacks.all.first(where: { $0.descriptor.id == selectedPackID }) else { return }
        isResolving = true
        defer { isResolving = false }
        let proposal: GMIntentProposal
        do {
            proposal = try await gm.proposeIntent(from: playerText, campaign: campaign)
            statusText = "Apple Intelligence proposed intent; the engine resolved it."
        } catch {
            proposal = GMIntentProposal(verb: "attempt", detail: playerText, narrationPrompt: "Narrate the consequence from the resolved roll.")
            statusText = "Apple Intelligence unavailable; direct intent went to the rules engine."
        }
        let seed = UInt64.random(in: .min ... .max)
        switch rules.resolve(intent: .init(verb: proposal.verb, detail: proposal.detail), in: campaign, using: pack, seed: seed) {
        case .accepted(let event):
            do {
                try campaign.apply(event)
                self.campaign = campaign
                recap = campaign.recap
                resultText = "\(pack.descriptor.mechanicFamily): \(event.payload["total"] ?? "?") • audit seed \(seed)"
                try? await store.save(campaign)
            } catch { resultText = "The campaign state rejected that event: \(error.localizedDescription)" }
        case .rejected(let reason): resultText = reason
        }
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
            recap = newCampaign.recap
            canResolveSRDAttack = true
            canResolveRiverShadeTurn = false
            srdSummary = profile.name + ", level 1 " + profile.characterClass + " • HP " + String(profile.maximumHitPoints) + " • AC " + String(profile.armorClass) + " • Your turn against the River Shade."
            statusText = "SRD 5.2.1 character and encounter saved locally."
            try await store.save(newCampaign)
        } catch {
            statusText = "Could not start the SRD encounter: " + error.localizedDescription
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
            recap = campaign.recap
            let targetHP = campaign.world.encounter?.combatants.first(where: { $0.id == "river-shade" })?.hitPoints ?? 0
            srdSummary = completion?.narration ?? ("Attack " + resolution.attack.outcome.rawValue + " • " + String(resolution.damage) + " damage • River Shade: " + String(targetHP) + " HP • audit seed " + String(seed))
            canResolveSRDAttack = false
            canResolveRiverShadeTurn = completion == nil && campaign.world.encounter?.activeCombatantID == LanternBelowEncounter.riverShadeID
            statusText = completion == nil ? "Your attack is recorded. The River Shade acts next." : "Encounter complete. " + campaign.world.quest.objective
            try await store.save(campaign)
        } catch {
            statusText = "The SRD engine rejected that attack: " + error.localizedDescription
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
            recap = campaign.recap
            let playerHP = campaign.world.encounter?.combatants.first(where: { $0.id == LanternBelowEncounter.playerID })?.hitPoints ?? 0
            srdSummary = completion?.narration ?? ("River Shade: " + resolution.attack.outcome.rawValue + " • " + String(resolution.damage) + " damage • " + LanternBelowEncounter.playerID + " HP: " + String(playerHP) + " • audit seed " + String(seed))
            canResolveRiverShadeTurn = false
            canResolveSRDAttack = completion == nil && campaign.world.encounter?.activeCombatantID == LanternBelowEncounter.playerID && playerHP > 0
            statusText = completion == nil ? "The River Shade’s turn is recorded. Your turn." : "Encounter complete. " + campaign.world.quest.objective
            try await store.save(campaign)
        } catch {
            statusText = "The SRD engine rejected the River Shade’s turn: " + error.localizedDescription
        }
    }

    private func applyEncounterCompletion(to campaign: inout CampaignState) throws -> LanternBelowEncounter.Completion? {
        guard let encounter = campaign.world.encounter, let result = LanternBelowEncounter.completionEvents(campaignID: campaign.id, encounter: encounter) else { return nil }
        for event in result.events { try campaign.apply(event) }
        return result.completion
    }
}
