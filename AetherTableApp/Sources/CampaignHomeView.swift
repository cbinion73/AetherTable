import AetherTableCore
import RulesPacks
import SwiftUI

struct CampaignHomeView: View {
    @State private var model = CampaignViewModel()
    @State private var creating = false
    var body: some View {
        Group {
            if model.campaign != nil { CampaignPlayView(model: model) }
            else {
                NavigationStack {
                    StoryPage {
                        StoryHeading(eyebrow: "AetherTable · Solo adventures", title: model.campaigns.isEmpty ? "A world awaits\nyour next move." : "Your stories,\nstill waiting.")
                        StoryCard {
                            Image(systemName: "flame").font(.largeTitle).foregroundStyle(StoryStyle.copper).accessibilityHidden(true)
                            Text("The world follows your words.").font(.system(.title2, design: .serif, weight: .bold))
                            Text("Meet strangers. Chase a rumor. Leave the road. Your Apple Intelligence Dungeon Master remembers the world you build together.").font(.system(.body, design: .serif)).lineSpacing(5)
                            Text("Four level-one classes · Open-world solo play\n5E-compatible SRD subset · Apple Intelligence required").font(.footnote).foregroundStyle(.secondary)
                            Button("Create your adventurer", systemImage: "plus") { creating = true }.buttonStyle(.borderedProminent).controlSize(.large).disabled(model.isResolving || !model.loaded)
                        }
                        ForEach(model.campaigns, id: \.id) { campaign in
                            let world = try? OpenWorldAdventure.from(campaign)
                            StoryAction(title: world?.hero.name ?? campaign.title, detail: "\(world?.hero.characterClass.rawValue ?? "Adventure") · \(world?.location ?? campaign.world.locationID) · \(world?.hero.hitPoints ?? 0) HP\n\((world?.transcript.last?.text ?? campaign.recap).prefix(160))") { model.select(campaign) }
                        }
                        if !model.unreadableFiles.isEmpty {
                            StoryCard { Label("Some campaigns could not be read", systemImage: "exclamationmark.triangle"); Text("These files were preserved. Other adventures are still available.").font(.subheadline); ForEach(model.unreadableFiles, id: \.self) { Text($0).font(.caption).textSelection(.enabled) } }
                        }
                        if model.isResolving { ProgressView("Opening your library…") }
                        Button("Refresh library") { Task { await model.start() } }.disabled(model.isResolving)
                    }.navigationTitle("Library").navigationBarTitleDisplayMode(.inline)
                }
            }
        }.tint(StoryStyle.copper)
            .task { if !model.loaded { await model.start() } }
            .sheet(isPresented: $creating) { CharacterCreationView(model: model) }
            .alert("Your story needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
    }
}


struct CampaignPlayView: View {
    let model: CampaignViewModel
    var body: some View {
        TabView {
            Tab("Adventure", systemImage: "book.pages") { NavigationStack { AdventureView(model: model) } }
            Tab("Character", systemImage: "person.crop.rectangle") { NavigationStack { CharacterView(model: model) } }
            Tab("Journal", systemImage: "text.book.closed") { NavigationStack { JournalView(model: model) } }
            Tab("Rules", systemImage: "dice") { NavigationStack { RulesView() } }
        }
    }
}
