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
            campaign.apply(event)
            self.campaign = campaign
            recap = campaign.recap
            resultText = "\(pack.descriptor.mechanicFamily): \(event.payload["total"] ?? "?") • audit seed \(seed)"
            try? await store.save(campaign)
        case .rejected(let reason): resultText = reason
        }
    }
}
