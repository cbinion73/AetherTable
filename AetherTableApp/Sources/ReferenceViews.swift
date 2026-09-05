import AetherTableCore
import RulesPacks
import SwiftUI
import UIKit

struct CharacterView: View {
    let model: CampaignViewModel
    var body: some View {
        StoryPage {
            if let world = model.adventure {
                let hero = world.hero
                VStack(alignment: .leading, spacing: 5) {
                    Text("AETHERTABLE CHARACTER SHEET").font(.caption.bold()).tracking(2).foregroundStyle(StoryStyle.copper)
                    Text(hero.name).font(.system(.largeTitle, design: .serif, weight: .bold))
                    Text("\(hero.creation?.species.rawValue ?? "Adventurer") · Level \(hero.level) \(hero.characterClass.rawValue) · \(hero.creation?.background.rawValue ?? "")").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(StoryStyle.parchment).overlay(Rectangle().stroke(StoryStyle.ink.opacity(0.75), lineWidth: 1.25))
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
                    if hero.spellcastingAbility != nil { LabeledContent("Level-one spell slots", value: "\(hero.spellSlots) / 2") }
                    if let features = hero.classFeatures {
                        if features.rageUses > 0 { LabeledContent("Rage", value: "\(features.rageUses) uses") }
                        if features.bardicInspirationUses > 0 { LabeledContent("Bardic Inspiration", value: "\(features.bardicInspirationUses) uses") }
                        if features.layOnHandsPool > 0 { LabeledContent("Lay on Hands", value: "\(features.layOnHandsPool) HP") }
                        if features.huntersMarkUses > 0 { LabeledContent("Hunter’s Mark", value: "\(features.huntersMarkUses) uses") }
                        if features.innateSorceryUses > 0 { LabeledContent("Innate Sorcery", value: "\(features.innateSorceryUses) uses") }
                    }
                }
                StoryCard {
                    Text("ABILITY SCORES").font(.caption.bold()).tracking(1.5).foregroundStyle(StoryStyle.copper)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                        ForEach(SRD521Ability.allCases, id: \.rawValue) { ability in
                            SheetAbilityTile(ability: ability.rawValue, score: hero.scores[ability, default: 10], modifier: hero.modifier(ability), proficient: hero.creation?.savingThrowProficiencies.contains(ability) ?? false)
                        }
                    }
                    Divider()
                    ForEach(hero.skills.keys.sorted(), id: \.self) { skill in LabeledContent(skill.capitalized, value: hero.skills[skill] == 4 ? "Expertise +4" : "Trained +2") }
                    Text("Training is added to the relevant ability modifier.").font(.caption).foregroundStyle(.secondary)
                }
                StoryCard {
                    Text("Equipment").font(.title2.bold())
                    ForEach(Array(hero.equipment.enumerated()), id: \.offset) { _, item in
                        let detail = inventoryDetail(for: item, in: world)
                        VStack(alignment: .leading) {
                            Text(item.capitalized).font(.headline)
                            if let detail { Text(detail).font(.subheadline).foregroundStyle(.secondary) }
                        }
                    }
                }
                if !hero.spells.isEmpty { StoryCard { Text("Known spells").font(.title2.bold()); ForEach(hero.spells, id: \.self) { Text($0.capitalized) }; Text("Describe spell use in the adventure. The rules engine spends slots and resolves attacks, saves or healing.").font(.footnote).foregroundStyle(.secondary) } }
                if let initiate = hero.magicInitiate { StoryCard { Text("Magic Initiate").font(.title2.bold()); Text("\(initiate.ability.rawValue.capitalized) casting · \(initiate.freeUsesRemaining)/1 free cast"); Text((initiate.cantrips + [initiate.spell]).map { $0.capitalized }.joined(separator: ", ")) } }
                StoryCard { Label("Creation backstory", systemImage: "lock").font(.headline); Text(world.creationBackstory ?? "No special pre-adventure history was established.").font(.system(.body, design: .serif)).textSelection(.enabled); Text("Fixed at creation. Relationships and experiences earned during play live in your journal.").font(.caption).foregroundStyle(.secondary) }
            }
        }.navigationTitle("Character").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let world = model.adventure {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Print sheet", systemImage: "printer") { CharacterSheetPrinter.printSheet(for: world) }
                    }
                }
            }
    }

    private func inventoryDetail(for item: String, in world: OpenWorldAdventure) -> String? {
        world.memories.first { memory in
            memory.category == "inventory" && memory.status == "active" && memory.name.caseInsensitiveCompare(item) == .orderedSame
        }?.detail
    }
}

/// A deliberately plain, high-contrast companion sheet for the real table.
/// The in-app sheet remains the authoritative interactive surface; this one is
/// sized for paper and contains no hidden game state.
@MainActor
private enum CharacterSheetPrinter {
    static func printSheet(for world: OpenWorldAdventure) {
        let hero = world.hero
        let abilities = SRD521Ability.allCases.map { ability in
            let score = hero.scores[ability, default: 10]
            return "<tr><td>\(escape(ability.rawValue.capitalized))</td><td class=\"number\">\(score)</td><td class=\"number\">\(hero.modifier(ability).formatted(.number.sign(strategy: .always())))</td></tr>"
        }.joined()
        let skills = hero.skills.keys.sorted().map { skill in
            "<li>\(escape(skill.capitalized)): \(hero.skills[skill] == 4 ? "Expertise +4" : "Trained +2")</li>"
        }.joined()
        let equipment = hero.equipment.map { "<li>\(escape($0.capitalized))</li>" }.joined()
        let spells = hero.spells.map { "<li>\(escape($0.capitalized))</li>" }.joined()
        let creation = hero.creation
        let html = """
        <!doctype html><html><head><meta charset=\"utf-8\"><style>
        @page { margin: 0.45in; } body { color:#22150d; font-family: Georgia, serif; font-size: 11pt; }
        h1 { margin:0; font-size:28pt; } h2 { border-bottom:2px solid #8b4513; font-size:13pt; letter-spacing:.08em; margin:20px 0 8px; text-transform:uppercase; }
        .sub { color:#70421c; font-weight:bold; letter-spacing:.08em; } .stats { display:table; width:100%; border-spacing:6px 0; margin:12px 0; }
        .stat { display:table-cell; border:1px solid #8b4513; text-align:center; padding:9px; } .stat b { display:block; font-size:20pt; }
        table { border-collapse:collapse; width:100%; } td, th { border:1px solid #8b4513; padding:6px; text-align:left; } .number { text-align:center; width:16%; }
        ul { margin:5px 0; padding-left:22px; } .note { border:1px solid #8b4513; min-height:70px; padding:8px; white-space:pre-wrap; }
        </style></head><body>
        <div class=\"sub\">AETHERTABLE · LEVEL \(hero.level) ADVENTURER</div>
        <h1>\(escape(hero.name))</h1>
        <p>\(escape(creation?.species.rawValue ?? "Adventurer")) · \(escape(hero.characterClass.rawValue)) · \(escape(creation?.background.rawValue ?? "")) · \(escape(creation?.alignment ?? ""))</p>
        <div class=\"stats\"><div class=\"stat\">ARMOR CLASS<b>\(hero.armorClass)</b></div><div class=\"stat\">HIT POINTS<b>\(hero.hitPoints) / \(hero.maximumHitPoints)</b></div><div class=\"stat\">SPEED<b>\(creation?.speed ?? 30) ft</b></div><div class=\"stat\">PROFICIENCY<b>+2</b></div></div>
        <h2>Ability Scores</h2><table><tr><th>Ability</th><th class=\"number\">Score</th><th class=\"number\">Modifier</th></tr>\(abilities)</table>
        <h2>Training & Features</h2><p><b>Saving Throws:</b> \(escape(creation?.savingThrowProficiencies.map { $0.rawValue.capitalized }.joined(separator: ", ") ?? "—"))</p><p><b>Skills:</b></p><ul>\(skills)</ul><p><b>Feats:</b> \(escape(creation?.feats.joined(separator: ", ") ?? "—"))</p>
        <h2>Equipment</h2><ul>\(equipment)</ul>
        \(spells.isEmpty ? "" : "<h2>Spells</h2><ul>\(spells)</ul>")
        <h2>Campaign Notes</h2><div class=\"note\">Location: \(escape(world.location))\n\n</div>
        </body></html>
        """
        let controller = UIPrintInteractionController.shared
        controller.printFormatter = UIMarkupTextPrintFormatter(markupText: html)
        controller.present(animated: true)
    }

    private static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
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
