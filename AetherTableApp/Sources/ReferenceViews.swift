import AetherTableCore
import RulesPacks
import SwiftUI

struct CharacterView: View {
    let model: CampaignViewModel
    var body: some View {
        StoryPage {
            if let world = model.adventure {
                let hero = world.hero
                StoryHeading(eyebrow: "Level \(hero.level) \(hero.characterClass.rawValue)", title: hero.name)
                if let creation = hero.creation {
                    StoryCard {
                        Text("\(creation.species.rawValue) · \(creation.background.rawValue)").font(.headline)
                        Text("\(creation.alignment) · \(creation.speed) ft speed · \(creation.size)").font(.subheadline)
                        Text("Saving throw proficiencies: \(creation.savingThrowProficiencies.map { $0.rawValue.capitalized }.joined(separator: ", "))").font(.footnote)
                        Text("Languages: \(creation.allLanguages.joined(separator: ", "))").font(.footnote)
                        Text("Feats: \(creation.feats.joined(separator: ", "))").font(.footnote)
                    }
                }
                StoryCard {
                    LabeledContent("Hit points", value: "\(hero.hitPoints) / \(hero.maximumHitPoints)")
                    LabeledContent("Armor Class", value: String(hero.armorClass))
                    LabeledContent("Proficiency bonus", value: "+2")
                    if hero.characterClass == .fighter { LabeledContent("Second Wind", value: "\(hero.secondWindUses) / 2 uses") }
                    if hero.characterClass == .wizard || hero.characterClass == .cleric { LabeledContent("Level-one spell slots", value: "\(hero.spellSlots) / 2") }
                }
                StoryCard {
                    Text("Abilities & training").font(.title2.bold())
                    ForEach(SRD521Ability.allCases, id: \.rawValue) { ability in LabeledContent(ability.rawValue.capitalized, value: "\(hero.scores[ability, default: 10]) (\(hero.modifier(ability).formatted(.number.sign(strategy: .always()))))") }
                    Divider()
                    ForEach(hero.skills.keys.sorted(), id: \.self) { skill in LabeledContent(skill.capitalized, value: hero.skills[skill] == 4 ? "Expertise +4" : "Trained +2") }
                    Text("Training is added to the relevant ability modifier.").font(.caption).foregroundStyle(.secondary)
                }
                StoryCard {
                    Text("Equipment").font(.title2.bold())
                    ForEach(Array(hero.equipment.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading) {
                            Text(item.capitalized).font(.headline)
                            if let detail = world.memories.first(where: { $0.category == "inventory" && $0.status == "active" && $0.name.lowercased() == item.lowercased() })?.detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
                        }
                    }
                }
                if !hero.spells.isEmpty { StoryCard { Text("Known spells").font(.title2.bold()); ForEach(hero.spells, id: \.self) { Text($0.capitalized) }; Text("Describe spell use in the adventure. The rules engine spends slots and resolves attacks, saves or healing.").font(.footnote).foregroundStyle(.secondary) } }
                if let initiate = hero.magicInitiate { StoryCard { Text("Magic Initiate").font(.title2.bold()); Text("\(initiate.ability.rawValue.capitalized) casting · \(initiate.freeUsesRemaining)/1 free cast"); Text((initiate.cantrips + [initiate.spell]).map { $0.capitalized }.joined(separator: ", ")) } }
                StoryCard { Label("Creation backstory", systemImage: "lock").font(.headline); Text(world.creationBackstory ?? "No special pre-adventure history was established.").font(.system(.body, design: .serif)).textSelection(.enabled); Text("Fixed at creation. Relationships and experiences earned during play live in your journal.").font(.caption).foregroundStyle(.secondary) }
            }
        }.navigationTitle("Character").navigationBarTitleDisplayMode(.inline)
    }
}
struct JournalView: View {
    let model: CampaignViewModel
    @State private var note = ""
    @State private var category = "All"
    var body: some View {
        StoryPage {
            StoryHeading(eyebrow: "The world remembers", title: "Your journal")
            if let world = model.adventure {
                StoryCard { Label(world.location, systemImage: "map").font(.headline); Text("\(world.turn) turns · \(world.transcript.count) saved messages\nYour full conversation remains in the adventure.").font(.subheadline).foregroundStyle(.secondary) }
                StoryCard {
                    Text("A note for your return").font(.headline)
                    TextField("Your note", text: $note, axis: .vertical).lineLimit(3...8)
                    Button("Save note") { Task { if await model.saveWorldNote(note) { note = "" } } }.buttonStyle(.bordered).disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isResolving)
                }
                Picker("Show", selection: $category) { ForEach(["All", "person", "place", "quest", "promise", "fact", "inventory"], id: \.self) { Text($0.capitalized).tag($0) } }.pickerStyle(.menu)
                ForEach(world.memories.filter { $0.status != "inactive" && (category == "All" || $0.category == category) }) { memory in
                    StoryCard { Text("\(memory.category.uppercased()) · \(memory.status)").font(.caption.bold()).foregroundStyle(StoryStyle.copper); Text(memory.name).font(.system(.title3, design: .serif, weight: .bold)); Text(memory.detail).textSelection(.enabled) }
                }
                if let campaign = model.campaign {
                    ForEach(campaign.events.filter { $0.kind == .noteAdded && $0.payload["type"] == "player" }) { event in StoryCard { Text("Your note").font(.headline); Text(event.payload["text"] ?? "") } }
                }
            }
        }.navigationTitle("Journal").navigationBarTitleDisplayMode(.inline)
    }
}
struct RulesView: View {
    @State private var query = ""
    @State private var catalog: RuleCatalog?
    @State private var error: String?
    var body: some View {
        List {
            Section("First edition rules") {
                Text("Level-one Fighter, Rogue, Wizard and Cleric presets. The GM interprets free text; the engine rolls and changes resources.")
                Text("Implemented: trained ability checks; weapon attacks and criticals; Fighter Second Wind and Defense; conditional Rogue Sneak Attack; Fire Bolt, Magic Missile, Sacred Flame, Guiding Bolt, Cure Wounds/Healing Word on yourself or a named person, Light and Mage Hand; one-hour short rests with Hit Die and Arcane Recovery; eight-hour long rests.")
                Text("This beta uses an SRD 5.2.1 subset. Full class/background feats, leveling, tactical movement, opportunity attacks, death saves, comprehensive equipment, additional spells and full spell conditions are not implemented. Presets have original quickstart histories rather than claiming full published background packages.").font(.footnote).foregroundStyle(.secondary)
            }
            if let catalog {
                if !query.isEmpty && catalog.search(query, limit: 100).isEmpty { ContentUnavailableView.search(text: query) }
                ForEach(query.isEmpty ? catalog.records : catalog.search(query, limit: 100).map(\.rule)) { rule in VStack(alignment: .leading, spacing: 8) { Text(rule.title).font(.headline); Text(rule.summary); Text("\(rule.enforcementStatus.rawValue) · SRD p. \(rule.sourcePage)").font(.caption).foregroundStyle(.secondary) }.padding(.vertical, 5) }
            }
            if let error { Text(error) }
            if let license = SRD521RulesPack.descriptor.license { Section("Attribution") { Text(license.attribution).font(.footnote); Link("Read the source SRD", destination: license.sourceURL); Text(license.licenseName).font(.caption) } }
        }.searchable(text: $query, prompt: "Search rules").navigationTitle("Rules")
            .task { do { catalog = try SRD521RuleCatalog.loadBundled() } catch { self.error = "The offline rule reference could not be loaded." } }
    }
}
