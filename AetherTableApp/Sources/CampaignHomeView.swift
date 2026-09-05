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
            .sheet(isPresented: $creating) { CharacterCreationEntryView(model: model) }
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
        }.alert("Welcome back", isPresented: Binding(get: { model.returnRecap != nil && !model.isShowingReturnRecap }, set: { _ in })) {
            Button("Show recap") { model.showReturnRecap() }
            Button("Continue without recap") { Task { await model.resumeAfterAbsence() } }
        } message: { Text("It has been more than a day since this campaign was played. Would you like a recap first?") }
        .sheet(isPresented: Binding(get: { model.isShowingReturnRecap }, set: { shown in if !shown { Task { await model.resumeAfterAbsence() } } })) {
            NavigationStack { StoryPage { StoryHeading(eyebrow: "Previously at the table", title: "Your return"); Text(model.returnRecap ?? "").font(.system(.body, design: .serif)).lineSpacing(6) }.navigationTitle("Campaign recap").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Continue") { Task { await model.resumeAfterAbsence() } } } } }
        }
    }
}

struct CharacterCreationEntryView: View {
    let model: CampaignViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var custom = false
    @State private var name = ""
    @State private var characterClass: AdventurerClass = .fighter
    @State private var opening = AdventureOpening.default

    var body: some View {
        NavigationStack {
            StoryPage {
                StoryHeading(eyebrow: "AetherTable", title: "Choose your path")
                StoryCard {
                    Label("Quickstart", systemImage: "bolt.shield").font(.title3.bold())
                    Text("Start a complete, rules-backed level-one hero in a minute. You choose a name, class, and the opening scene; the game supplies a usable build.").font(.system(.body, design: .serif))
                    TextField("Character name", text: $name).textInputAutocapitalization(.words)
                    Picker("Class", selection: $characterClass) { ForEach(AdventurerClass.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    openingFields
                    Button("Start quick adventure") { Task { if await model.createAdventure(name: name, characterClass: characterClass, backstory: "", opening: opening) { dismiss() } } }
                        .buttonStyle(.borderedProminent).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !opening.isValid || model.isResolving)
                }
                StoryCard {
                    Label("Custom character", systemImage: "person.text.rectangle").font(.title3.bold())
                    Text("Use the full D&D-inspired character workflow: species, background, ability scores, training, magic, equipment, backstory, and an opening brief.").font(.system(.body, design: .serif))
                    Button("Build a custom character") { custom = true }.buttonStyle(.bordered)
                }
            }.navigationTitle("New adventure").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }.sheet(isPresented: $custom) { CharacterCreationView(model: model) }.tint(StoryStyle.copper)
    }

    private var openingFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Opening scene").font(.headline)
            TextField("Where are you?", text: $opening.place)
            TextField("What are you doing?", text: $opening.activity)
            TextField("Who are you with?", text: $opening.companions)
            TextField("Why are you here?", text: $opening.reason)
            TextField("Initial campaign story", text: $opening.premise, axis: .vertical).lineLimit(3...5)
        }
    }
}
