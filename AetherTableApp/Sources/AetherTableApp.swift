import AetherTableCore
import DiceEngine
import RulesPacks
import SwiftUI

@main
struct AetherTableApp: App { var body: some Scene { WindowGroup { CampaignHomeView() } } }

struct CampaignHomeView: View {
    @State private var selectedPackID: RulesPackID = BuiltInRulesPacks.all[0].descriptor.id
    @State private var rollText = "Ready to roll"

    var body: some View {
        NavigationStack {
            Form {
                Section("One platform. Many worlds.") {
                    Text("AetherTable keeps the campaign truth in the engine. The AI Game Master brings it to life.")
                }
                Section("Rules Pack") {
                    Picker("Prototype", selection: $selectedPackID) {
                        ForEach(BuiltInRulesPacks.all, id: \.descriptor.id) { pack in
                            Text(pack.descriptor.displayName).tag(pack.descriptor.id)
                        }
                    }
                    let pack = BuiltInRulesPacks.all.first { $0.descriptor.id == selectedPackID }!
                    Text("\(pack.descriptor.mechanicFamily) • \(pack.descriptor.actionVerbs.joined(separator: ", "))")
                        .foregroundStyle(.secondary)
                }
                Section("Deterministic Dice") {
                    Text(rollText).monospacedDigit()
                    Button("Roll d20") {
                        let seed = UInt64.random(in: .min ... .max)
                        let roll = try? DiceEngine.roll(DiceExpression(count: 1, sides: 20, modifier: 0), seed: seed)
                        rollText = "d20: \(roll?.total ?? 0)  •  audit seed \(roll?.seed ?? 0)"
                    }
                }
                Section("Next") { Text("Create a solo campaign, persist its event log, then introduce shared turns through an Apple-native sync transport.") }
            }
            .navigationTitle("AetherTable")
        }
    }
}
