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
                            HStack { Label("\(state.hero.hitPoints)/\(state.hero.maximumHitPoints) HP", systemImage: "heart"); Text("AC \(state.hero.armorClass)"); if state.hero.spellcastingAbility != nil { Text("\(state.hero.spellSlots) spell slots") } }.font(.caption.bold()).foregroundStyle(.secondary)
                            if !state.transcript.isEmpty {
                                DisclosureGroup("Why am I here?") {
                                    Text(state.opening.briefing).font(.system(.body, design: .serif)).lineSpacing(5).padding(.top, 4)
                                }.font(.caption.bold()).tint(StoryStyle.copper)
                            }
                            if let features = state.hero.classFeatures {
                                Text(featureSummary(features)).font(.caption).foregroundStyle(StoryStyle.copper).frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if state.transcript.isEmpty {
                                StoryCard {
                                    Label("The opening scene", systemImage: "theatermasks").font(.headline)
                                    Text(state.opening.briefing).font(.system(.body, design: .serif)).lineSpacing(5)
                                    Divider()
                                    Text("Your Dungeon Master will begin from this moment. After that, every choice is yours to write.").font(.subheadline).foregroundStyle(.secondary)
                                    Button("Begin adventure") { model.send(opening: true) }.buttonStyle(.borderedProminent).disabled(model.isResolving)
                                }
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
            .sheet(item: Binding(get: { model.diceRoll }, set: { if $0 == nil { model.cancelDiceRoll() } })) { roll in
                DiceRollView(model: model, initialRoll: roll)
                    .interactiveDismissDisabled(true)
            }
            .sheet(isPresented: Binding(get: { receipt != nil }, set: { if !$0 { receipt = nil } })) { NavigationStack { StoryPage { StoryHeading(eyebrow: "Engine record", title: "Dice & consequences"); Text(receipt ?? "").font(.body.monospaced()).textSelection(.enabled) }.toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { receipt = nil } } } } }
    }
}

private func featureSummary(_ features: ClassFeatureState) -> String {
    let entries = [
        features.rageUses > 0 ? "Rage \(features.rageUses)" : nil,
        features.bardicInspirationUses > 0 ? "Inspiration \(features.bardicInspirationUses)" : nil,
        features.layOnHandsPool > 0 ? "Lay on Hands \(features.layOnHandsPool)" : nil,
        features.huntersMarkUses > 0 ? "Hunter’s Mark \(features.huntersMarkUses)" : nil,
        features.innateSorceryUses > 0 ? "Innate Sorcery \(features.innateSorceryUses)" : nil,
        features.rageActive ? "Raging" : nil, features.innateSorceryActive ? "Innate Sorcery active" : nil,
        features.markedTarget.map { "Marked: \($0)" }, features.bardicInspirationTarget.map { "Inspired: \($0)" }
    ].compactMap { $0 }
    return entries.isEmpty ? "No class resources remaining" : entries.joined(separator: " · ")
}

private struct DiceRollView: View {
    @Bindable var model: CampaignViewModel
    let initialRoll: DiceRollState
    @State private var spinning = false

    private var roll: DiceRollState { model.diceRoll ?? initialRoll }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.07, blue: 0.035), Color(red: 0.28, green: 0.12, blue: 0.04), Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Image("RollingD20")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 330, maxHeight: 330)
                    .shadow(color: .orange.opacity(0.7), radius: spinning ? 34 : 16)
                    .rotationEffect(.degrees(spinning ? 1_440 : 0))
                    .scaleEffect(spinning ? 0.86 : 1)
                    .accessibilityLabel("Photorealistic twenty-sided die")
                Text(roll.title.uppercased())
                    .font(.caption.bold()).tracking(2.4).foregroundStyle(Color.orange.opacity(0.9))
                Text(roll.reason)
                    .font(.system(.body, design: .serif)).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.84)).padding(.horizontal, 24)

                if let raw = roll.rolledD20, let resolution = roll.resolution {
                    VStack(spacing: 8) {
                        Text("d20 · \(raw)").font(.system(size: 38, weight: .bold, design: .serif)).foregroundStyle(.white)
                        Text(resolution.outcome.uppercased()).font(.caption.bold()).tracking(2).foregroundStyle(resolution.outcome.contains("Success") || resolution.outcome.contains("hit") ? Color.green.opacity(0.9) : Color.orange.opacity(0.9))
                        if let line = roll.resultLine { Text(line).font(.footnote.monospaced()).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8)).padding(.horizontal, 20) }
                    }
                    Button("Continue to consequence", systemImage: "text.book.closed") { model.continueAfterDice() }
                        .buttonStyle(.borderedProminent).tint(StoryStyle.copper).controlSize(.large).padding(.top, 4)
                } else {
                    Button(roll.isRolling ? "Rolling…" : "Roll the d20", systemImage: "dice") { model.rollDice() }
                        .buttonStyle(.borderedProminent).tint(StoryStyle.copper).controlSize(.large).disabled(roll.isRolling)
                    if !roll.isRolling { Button("Revise action") { model.cancelDiceRoll() }.foregroundStyle(.white.opacity(0.7)) }
                }
            }
            .padding(24)
        }
        .onChange(of: roll.isRolling, initial: true) { _, isRolling in
            withAnimation(.easeInOut(duration: 0.7), { spinning = isRolling })
        }
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
