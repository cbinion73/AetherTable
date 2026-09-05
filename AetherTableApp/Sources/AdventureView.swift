import AetherTableCore
import RulesPacks
import SwiftUI

struct AdventureView: View {
    @Bindable var model: CampaignViewModel
    @State private var receipt: String?
    @FocusState private var composing: Bool
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        if let state = model.adventure {
                            StoryHeading(eyebrow: "\(state.hero.name) · \(state.hero.characterClass.rawValue)", title: state.location)
                            HStack { Label("\(state.hero.hitPoints)/\(state.hero.maximumHitPoints) HP", systemImage: "heart"); Text("AC \(state.hero.armorClass)"); if state.hero.characterClass == .wizard || state.hero.characterClass == .cleric { Text("\(state.hero.spellSlots) spell slots") } }.font(.caption.bold()).foregroundStyle(.secondary)
                            if state.transcript.isEmpty {
                                StoryCard { Text("Your Dungeon Master is ready to meet you.").font(.system(.title2, design: .serif)); Text("Apple Intelligence brings this world to life. Your words decide where the adventure goes.").foregroundStyle(.secondary); Button("Begin adventure") { model.send(opening: true) }.buttonStyle(.borderedProminent).disabled(model.isResolving) }
                            }
                            ForEach(state.transcript) { message in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(message.role == "player" ? "\(state.hero.name.uppercased())" : message.role == "note" ? "YOUR NOTE" : "DUNGEON MASTER").font(.caption2.bold()).tracking(1.8).foregroundStyle(StoryStyle.copper)
                                    Text(message.text).font(.system(.body, design: message.role == "player" ? .default : .serif)).lineSpacing(6).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                    if let detail = message.receipt { Button("View dice & consequences", systemImage: "dice") { receipt = detail }.font(.caption).frame(minHeight: 44) }
                                }.padding(message.role == "player" ? 16 : 0).frame(maxWidth: .infinity, alignment: .leading).background(message.role == "player" ? Color.primary.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 16)).id(message.id)
                            }
                        }
                        if model.isResolving { ProgressView(model.turnStatus).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading) }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(22).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: model.adventure?.transcript.count) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            }
            VStack(spacing: 8) {
                TextField("What do you do or say?", text: $model.draft, axis: .vertical).lineLimit(2...6).focused($composing).padding(12).background(.background, in: RoundedRectangle(cornerRadius: 14)).accessibilityIdentifier("adventureComposer").disabled(model.isResolving)
                HStack {
                    Text("Apple Intelligence · Saved on this device").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    if model.isResolving { Button("Cancel") { model.cancelTurn() }.disabled(model.isSaving).frame(minHeight: 44) }
                    else { Button("Send", systemImage: "arrow.up") { composing = false; model.send() }.buttonStyle(.borderedProminent).disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).frame(minHeight: 44) }
                }
            }.padding(.horizontal, 16).padding(.top, 10).background(.bar)
        }.background(StoryStyle.parchment).navigationTitle("Adventure").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Library", systemImage: "books.vertical") { model.leave() }.disabled(model.isResolving) } }
            .sheet(isPresented: Binding(get: { receipt != nil }, set: { if !$0 { receipt = nil } })) { NavigationStack { StoryPage { StoryHeading(eyebrow: "Engine record", title: "Dice & consequences"); Text(receipt ?? "").font(.body.monospaced()).textSelection(.enabled) }.toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { receipt = nil } } } } }
    }
}

/// Legacy receipt support for imported campaigns.
struct DiceDetailView: View {
    let campaign: CampaignState
    var eventID: UUID? = nil
    var body: some View {
        StoryPage {
            if let event = campaign.events.last(where: { eventID == nil ? $0.kind == .actionResolved : $0.id == eventID }) {
                ForEach(event.payload.keys.sorted(), id: \.self) { key in LabeledContent(key, value: event.payload[key] ?? "") }
            }
        }.navigationTitle("Legacy roll")
    }
}
