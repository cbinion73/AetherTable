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
                    CampaignTablePage {
                        CampaignTableHeader()
                        TabletopHeroArt()
                        VStack(alignment: .leading, spacing: 8) {
                            WaxSeal(label: model.campaigns.isEmpty ? "The table is set" : "Your next chapter")
                            Text(model.campaigns.isEmpty ? "Where will your\nlegend begin?" : "Your stories are\nwaiting at the table.")
                                .font(.system(size: 36, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                            Text("A solo fantasy campaign shaped by your words, backed by real dice and a world that remembers.")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.75)).lineSpacing(3)
                        }.padding(.vertical, 4)
                        CampaignPanel {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("START A CAMPAIGN").font(.caption2.bold()).tracking(1.7).foregroundStyle(StoryStyle.copper)
                                    Text("Make an adventurer").font(.system(.title2, design: .serif, weight: .bold))
                                    Text("Quickstart in a minute, or build every detail yourself.").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "person.crop.circle.badge.plus").font(.title).foregroundStyle(StoryStyle.copper)
                            }
                            Button("Create your adventurer", systemImage: "plus") { creating = true }
                                .buttonStyle(TabletopPrimaryButtonStyle()).disabled(model.isResolving || !model.loaded)
                        }
                        CampaignPanel {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "sun.max.fill").font(.title2).foregroundStyle(StoryStyle.copper)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("FEATURED ADVENTURE").font(.caption2.bold()).tracking(1.5).foregroundStyle(StoryStyle.copper)
                                    Text("The Shining Road").font(.system(.title2, design: .serif, weight: .bold))
                                    Text("A bright festival, an observatory mystery, people worth knowing, and a dozen ways to make the day your own.").font(.system(.subheadline, design: .serif)).foregroundStyle(.secondary)
                                }
                            }
                            Button("Set out on the Shining Road", systemImage: "sparkles") { Task { _ = await model.createShiningRoadPlaytest() } }
                                .buttonStyle(.bordered).tint(StoryStyle.copper).disabled(model.isResolving || !model.loaded)
                        }
                        if !model.campaigns.isEmpty {
                            Text("OPEN CAMPAIGNS").font(.caption.bold()).tracking(2).foregroundStyle(StoryStyle.candle)
                        }
                        ForEach(model.campaigns, id: \.id) { campaign in
                            let world = try? OpenWorldAdventure.from(campaign)
                            CampaignPanel {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(world?.hero.name ?? campaign.title).font(.system(.title3, design: .serif, weight: .bold))
                                        Text("\(world?.hero.characterClass.rawValue ?? "Adventure") · \(world?.location ?? campaign.world.locationID) · \(world?.hero.hitPoints ?? 0) HP").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "bookmark.fill").foregroundStyle(StoryStyle.copper)
                                }
                                Text((world?.transcript.last?.text ?? campaign.recap).prefix(160)).font(.footnote).foregroundStyle(.secondary).lineLimit(3)
                                Button("Return to campaign", systemImage: "arrow.right") { model.select(campaign) }.buttonStyle(.bordered).tint(StoryStyle.copper)
                            }
                        }
                        if !model.unreadableFiles.isEmpty {
                            StoryCard { Label("Some campaigns could not be read", systemImage: "exclamationmark.triangle"); Text("These files were preserved. Other adventures are still available.").font(.subheadline); ForEach(model.unreadableFiles, id: \.self) { Text($0).font(.caption).textSelection(.enabled) } }
                        }
                        if model.isResolving { ProgressView("Opening your library…") }
                        Button("Refresh campaign chronicle", systemImage: "arrow.clockwise") { Task { await model.start() } }
                            .font(.footnote).foregroundStyle(.white.opacity(0.65)).disabled(model.isResolving)
                    }.toolbar(.hidden, for: .navigationBar)
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
        }.toolbarBackground(StoryStyle.parchment, for: .tabBar).toolbarBackground(.visible, for: .tabBar).alert("Welcome back", isPresented: Binding(get: { model.returnRecap != nil && !model.isShowingReturnRecap }, set: { _ in })) {
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
                    Text("Choose a class").font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                        ForEach(AdventurerClass.allCases, id: \.self) { option in
                            Button(option.rawValue) { characterClass = option }
                                .buttonStyle(QuickstartClassChoiceStyle(isSelected: characterClass == option))
                        }
                    }
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

private struct QuickstartClassChoiceStyle: ButtonStyle {
    let isSelected: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, minHeight: 42)
            .foregroundStyle(isSelected ? .white : StoryStyle.ink)
            .background(isSelected ? StoryStyle.seal : StoryStyle.parchment.opacity(0.94))
            .overlay(Rectangle().stroke(isSelected ? StoryStyle.gilded : StoryStyle.border.opacity(0.65), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
