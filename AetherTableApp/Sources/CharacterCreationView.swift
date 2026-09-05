import RulesPacks
import SwiftUI

private enum CreationStage: String, CaseIterable {
    case identity = "Identity", abilities = "Abilities", training = "Training", magic = "Magic", equipment = "Equipment", backstory = "Backstory", opening = "Opening", review = "Review"
}

struct CharacterCreationView: View {
    let model: CampaignViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CharacterCreationDraft.suggested(for: .fighter)
    @State private var backstory = ""
    @State private var opening = AdventureOpening.default
    @State private var stage = CreationStage.identity
    private var index: Int { CreationStage.allCases.firstIndex(of: stage)! }
    private var errors: [String] { draft.validationErrors + (backstory.count > 4000 ? ["Backstory must be 4,000 characters or fewer."] : []) + (!opening.isValid ? ["Complete each part of the opening setup (800 characters maximum per field)."] : []) }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("STEP \(index + 1) OF \(CreationStage.allCases.count)").font(.caption.bold()).tracking(1.5); Spacer(); Text("Level 1 · SRD 5.2.1").font(.caption) }
                    ProgressView(value: Double(index + 1), total: Double(CreationStage.allCases.count)).tint(StoryStyle.copper)
                }.foregroundStyle(.secondary).padding(.horizontal, 22).padding(.vertical, 12)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        StoryHeading(eyebrow: "Create your adventurer", title: stage.rawValue)
                        switch stage {
                        case .identity: identity
                        case .abilities: abilities
                        case .training: training
                        case .magic: magic
                        case .equipment: equipment
                        case .backstory: origin
                        case .opening: openingSetup
                        case .review: review
                        }
                    }.padding(22).frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity)
                }.id(stage).scrollDismissesKeyboard(.interactively)
                HStack {
                    if index > 0 { Button("Back") { stage = CreationStage.allCases[index - 1] }.frame(minHeight: 44) }
                    Spacer()
                    if stage == .review {
                        Button("Create adventure") {
                            Task { if await model.createAdventure(character: draft, backstory: backstory, opening: opening) { dismiss() } }
                        }.buttonStyle(.borderedProminent).disabled(!errors.isEmpty || model.isResolving)
                    } else {
                        Button("Continue") { stage = CreationStage.allCases[index + 1] }.buttonStyle(.borderedProminent)
                    }
                }.padding(.horizontal, 22).padding(.vertical, 12).background(.bar).disabled(model.isResolving)
            }.background(StoryStyle.parchment).navigationTitle("Character creation").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(model.isResolving) } }
        }.interactiveDismissDisabled(model.isResolving).tint(StoryStyle.copper)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Build a character whose choices matter in the world and on the dice. Every selection remains editable until you create the adventure.").font(.system(.body, design: .serif))
            StoryCard {
                TextField("Character name", text: $draft.name).textContentType(.givenName).textInputAutocapitalization(.words).accessibilityIdentifier("characterName")
                Picker("Class", selection: Binding(get: { draft.characterClass }, set: { draft.changeClass(to: $0) })) {
                    ForEach(AdventurerClass.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Text(classDescription).font(.subheadline).foregroundStyle(.secondary)
            }
            StoryCard {
                Picker("Species", selection: $draft.species) { ForEach(CharacterSpecies.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                if draft.species == .human { Toggle("Small-sized Human", isOn: $draft.humanSmall) }
                Text(speciesDescription).font(.subheadline).foregroundStyle(.secondary)
                Picker("Background", selection: Binding(get: { draft.background }, set: changeBackground)) {
                    ForEach(CharacterBackground.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Text("Skills: \(draft.background.skills.map { $0.capitalized }.joined(separator: ", "))\nOrigin feat: \(draft.background.feat)").font(.subheadline)
                Text("Your rules background supplies training and an Origin feat. Your own written backstory supplies the people, places and experiences behind it.").font(.footnote).foregroundStyle(.secondary)
            }
            StoryCard {
                Picker("Alignment", selection: $draft.alignment) {
                    ForEach(["Lawful Good", "Neutral Good", "Chaotic Good", "Lawful Neutral", "Neutral", "Chaotic Neutral", "Lawful Evil", "Neutral Evil", "Chaotic Evil"], id: \.self) { Text($0).tag($0) }
                }
                TextField("Appearance (optional)", text: $draft.appearance, axis: .vertical).lineLimit(2...5)
            }
        }
    }

    private var abilities: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                ForEach(AbilityGenerationMethod.allCases, id: \.self) { method in
                    Button { draft.method = method } label: {
                        Text(method.rawValue).font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(draft.method == method ? StoryStyle.copper : Color.clear, in: Capsule())
                            .foregroundStyle(draft.method == method ? Color.white : StoryStyle.copper)
                    }.buttonStyle(.plain).accessibilityAddTraits(draft.method == method ? .isSelected : [])
                }
            }
            StoryCard {
                if draft.method == .pointBuy {
                    HStack { Text("Points remaining").font(.headline); Spacer(); Text("\(draft.pointsRemaining) / 27").font(.title2.monospacedDigit().bold()).foregroundStyle(draft.pointsRemaining < 0 ? .red : StoryStyle.copper) }
                    Text("Scores 8–13 cost one point per increase. 14 and 15 cost two points each. Base scores cannot exceed 15.").font(.footnote).foregroundStyle(.secondary)
                    Button("Reset all base scores to 8") {
                        for ability in CharacterCreationDraft.abilities { draft.baseScores[ability] = 8 }
                    }.font(.subheadline).frame(minHeight: 44)
                } else { Text("Assign 15, 14, 13, 12, 10 and 8 once each. Background increases are added below.").font(.subheadline) }
                ForEach(CharacterCreationDraft.abilities, id: \.self) { ability in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            VStack(alignment: .leading) { Text(ability.rawValue.capitalized).font(.headline); Text(abilityDescription(ability)).font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            if draft.method == .pointBuy { allocationButtons(ability) }
                            else { Picker(ability.rawValue.capitalized, selection: scoreBinding(ability)) { ForEach(CharacterCreationDraft.standardArray, id: \.self) { Text(String($0)).tag($0) } }.labelsHidden() }
                        }
                        HStack { Text("Final \(draft.finalScores[ability, default: 8])"); Spacer(); Text("Modifier \(signed(draft.modifier(ability)))") }.font(.caption).foregroundStyle(.secondary)
                        if ability != .charisma { Divider() }
                    }
                }
            }
            StoryCard {
                Text("\(draft.background.rawValue) ability increases").font(.headline)
                Text("Assign +2 and +1 to two different eligible abilities, or +1 to all three.").font(.subheadline).foregroundStyle(.secondary)
                ForEach(draft.background.abilities, id: \.self) { ability in
                    Stepper("\(ability.rawValue.capitalized): +\(draft.backgroundBoosts[ability, default: 0])", value: Binding(get: { draft.backgroundBoosts[ability, default: 0] }, set: { draft.backgroundBoosts[ability] = $0 }), in: 0...2)
                }
            }
            derivedSummary
            if draft.method == .pointBuy && draft.pointsRemaining != 0 {
                Label("Allocate all 27 points before creating your character.", systemImage: "info.circle").font(.subheadline)
            }
            if draft.method == .standardArray && draft.baseScores.values.sorted() != CharacterCreationDraft.standardArray.sorted() {
                Label("Use each standard-array score exactly once. One or more scores are repeated or missing.", systemImage: "exclamationmark.circle").font(.subheadline)
            }
        }
    }

    private var training: some View {
        VStack(alignment: .leading, spacing: 20) {
            if draft.characterClass == .fighter { StoryCard { Picker("Fighting Style", selection: $draft.fightingStyle) { ForEach(FighterStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) } } } }
            if draft.characterClass == .cleric {
                StoryCard {
                    Picker("Divine Order", selection: $draft.divineOrder) { ForEach(ClericDivineOrder.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    Text(draft.divineOrder == .protector ? "Protector grants martial-weapon and heavy-armor proficiency." : "Thaumaturge grants an extra Cleric cantrip and a Wisdom-based bonus to Intelligence (Arcana and Religion) checks.").font(.footnote)
                }
            }
            selectionList("Class skills", choices: draft.availableClassSkills.filter { !draft.background.skills.contains($0) }, selected: $draft.classSkills, count: draft.requiredClassSkillCount)
            if draft.species == .human {
                StoryCard {
                    Picker("Human skill", selection: $draft.humanSkill) { ForEach(CharacterCreationDraft.allSkills.filter { !(draft.background.skills + draft.classSkills).contains($0) }, id: \.self) { Text($0.capitalized).tag($0) } }
                    Picker("Human Origin feat", selection: $draft.humanFeat) { ForEach(HumanOriginFeat.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                }
                if draft.humanFeat == .skilled { selectionList("Skilled proficiencies", choices: CharacterCreationDraft.allSkills.filter { !(draft.background.skills + draft.classSkills + [draft.humanSkill]).contains($0) }, selected: $draft.skilledSkills, count: 3) }
            }
            if draft.characterClass == .rogue { selectionList("Expertise", choices: draft.trainedSkills, selected: $draft.expertise, count: 2) }
            if draft.characterClass == .fighter || draft.characterClass == .rogue { selectionList("Weapon Mastery", choices: draft.availableMasteryWeapons, selected: $draft.masteryWeapons, count: draft.characterClass == .fighter ? 3 : 2) }
            selectionList("Languages in addition to Common", choices: CharacterCreationDraft.standardLanguages, selected: $draft.languages, count: 2)
            if draft.characterClass == .rogue { StoryCard { Text("Thieves’ Cant is included.").font(.footnote); Picker("Additional language", selection: $draft.rogueExtraLanguage) { ForEach(CharacterCreationDraft.standardLanguages.filter { !draft.languages.contains($0) }, id: \.self) { Text($0).tag($0) } } } }
        }
    }

    private var magic: some View {
        VStack(alignment: .leading, spacing: 20) {
            if draft.requiredCantripCount > 0 { selectionList("Class cantrips", choices: draft.availableCantrips, selected: $draft.cantrips, count: draft.requiredCantripCount) }
            if draft.characterClass == .wizard {
                selectionList("Spellbook", choices: draft.availableLevelOneSpells, selected: Binding(get: { draft.spellbook }, set: { draft.spellbook = $0; draft.preparedSpells = draft.preparedSpells.filter { draft.spellbook.contains($0) } }), count: 6)
                selectionList("Prepared spells", choices: draft.spellbook.sorted(), selected: $draft.preparedSpells, count: 4)
            } else if draft.characterClass == .cleric { selectionList("Prepared spells", choices: draft.availableLevelOneSpells, selected: $draft.preparedSpells, count: 4) }
            if let originClass = draft.background.spellClass {
                StoryCard {
                    Text(draft.background.feat).font(.title3.bold())
                    Text("Two cantrips and one first-level spell. Choose its casting ability separately. The granted spell has one free cast per long rest.").font(.subheadline)
                    Picker("Casting ability", selection: $draft.originSpellAbility) { ForEach([SRD521Ability.intelligence, .wisdom, .charisma], id: \.self) { Text($0.rawValue.capitalized).tag($0) } }
                    Picker("Granted spell", selection: $draft.originSpell) { ForEach(CharacterCreationDraft.levelOneSpells(for: originClass), id: \.self) { Text($0.capitalized).tag($0) } }
                }
                selectionList("Magic Initiate cantrips", choices: CharacterCreationDraft.cantrips(for: originClass), selected: $draft.originCantrips, count: 2)
            }
            if draft.requiredCantripCount == 0 && draft.background.spellClass == nil { StoryCard { Text("No spellcasting is granted by these level-one choices.").font(.system(.title3, design: .serif)); Text("Your background and class still shape the approaches available to you.").foregroundStyle(.secondary) } }
        }
    }

    private var equipment: some View {
        VStack(alignment: .leading, spacing: 20) {
            StoryCard {
                Picker("Class equipment", selection: $draft.equipmentChoice) { ForEach(StartingEquipmentChoice.allCases.filter { draft.characterClass == .fighter || $0 != .packageB }, id: \.self) { Text($0.rawValue).tag($0) } }
                Toggle("Take 50 GP instead of background equipment", isOn: $draft.backgroundEquipmentGold)
                if draft.background == .soldier && !draft.backgroundEquipmentGold { Picker("Gaming set", selection: $draft.gamingSet) { ForEach(["Dice Set", "Dragonchess Set", "Playing Card Set", "Three-Dragon Ante Set"], id: \.self) { Text($0).tag($0) } } }
                Divider()
                ForEach(Array(draft.startingEquipment.enumerated()), id: \.offset) { _, item in Text(item) }
            }
            derivedSummary
            if draft.equipmentChoice == .gold { Text("Starting with gold means no class weapons or armor are equipped. Equipment must be acquired in the world before it can be used.").font(.footnote).foregroundStyle(.secondary) }
        }
    }

    private var origin: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your past becomes part of the world.").font(.system(.title2, design: .serif, weight: .bold))
            Text("Record the family, places, relationships, education and experiences your character can draw upon. Connections and relevant experience can influence the story and fair rulings; they do not grant free class features or automatic success.").font(.system(.body, design: .serif))
            StoryCard {
                TextField("Write your character’s backstory", text: $backstory, axis: .vertical).lineLimit(10...18).accessibilityIdentifier("creationBackstory")
                Text("\(backstory.count) / 4,000 characters").font(.caption.monospacedDigit()).foregroundStyle(backstory.count > 4000 ? .red : .secondary)
            }
            Label("Locked when the adventure begins", systemImage: "lock").font(.headline)
            Text("You cannot add a noble parent, old friend, special upbringing or earlier training later to gain an advantage. Leaving this blank means no special pre-adventure history is established. New relationships and experiences can still be earned during play.").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var openingSetup: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set the first scene").font(.system(.title2, design: .serif, weight: .bold))
            Text("This becomes the campaign's opening truth. The Dungeon Master uses it to establish where you are, what you are doing, who is present, why you came, and the trouble that starts the story.").font(.system(.body, design: .serif))
            StoryCard {
                TextField("Where are you?", text: $opening.place, axis: .vertical).lineLimit(2...4)
                TextField("What are you doing when the story opens?", text: $opening.activity, axis: .vertical).lineLimit(2...4)
                TextField("Who are you with? (or ‘alone’)", text: $opening.companions, axis: .vertical).lineLimit(2...4)
                TextField("Why are you here?", text: $opening.reason, axis: .vertical).lineLimit(2...4)
                TextField("What is the initial campaign story?", text: $opening.premise, axis: .vertical).lineLimit(4...8)
            }
            Text("You will still decide every action in your own words. This briefing gives the world a real first moment; it does not put the story on rails.").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var review: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(draft.name.isEmpty ? "Your adventurer" : draft.name).font(.system(.largeTitle, design: .serif, weight: .bold))
            Text("\(draft.species.rawValue) · \(draft.characterClass.rawValue) · \(draft.background.rawValue)").font(.headline)
            derivedSummary
            StoryCard {
                ForEach(CharacterCreationDraft.abilities, id: \.self) { ability in LabeledContent(ability.rawValue.capitalized, value: "\(draft.finalScores[ability, default: 8]) (\(signed(draft.modifier(ability))))") }
                Divider()
                Text("Saving throw proficiencies: \(draft.savingThrowProficiencies.map { $0.rawValue.capitalized }.joined(separator: ", "))").font(.subheadline)
                Text("Skills: \(draft.trainedSkills.map { $0.capitalized }.joined(separator: ", "))").font(.subheadline)
                Text("Feats: \(draft.feats.joined(separator: ", "))").font(.subheadline)
            }
            StoryCard { Text("Creation backstory").font(.headline); Text(backstory.isEmpty ? "No special pre-adventure history established." : backstory).font(.system(.body, design: .serif)); Label("This history is fixed after creation.", systemImage: "lock").font(.caption).foregroundStyle(.secondary) }
            StoryCard { Text("Opening scene").font(.headline); Text(opening.briefing).font(.system(.body, design: .serif)).lineSpacing(4) }
            if !errors.isEmpty {
                StoryCard { Label("Finish these choices", systemImage: "exclamationmark.circle").font(.headline); ForEach(errors, id: \.self) { Text($0).font(.subheadline) } }
            }
            if !draft.manualAdjudicationNotes.isEmpty {
                DisclosureGroup("Current rules coverage") { ForEach(draft.manualAdjudicationNotes, id: \.self) { Text($0).font(.footnote).padding(.vertical, 4) } }
            }
            if model.isResolving { ProgressView("Saving your character and origin…") }
            if let error = model.error {
                StoryCard { Label("Character not saved", systemImage: "exclamationmark.triangle").font(.headline); Text(error).font(.subheadline) }
            }
        }
    }

    private var derivedSummary: some View {
        StoryCard {
            HStack { Label("\(draft.maximumHitPoints) HP", systemImage: "heart"); Spacer(); Text("AC \(draft.armorClass)"); Spacer(); Text("\(draft.speed) ft") }.font(.headline)
            Text("Derived from your class, scores, species, armor and features.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private func selectionList(_ title: String, choices: [String], selected: Binding<[String]>, count: Int) -> some View {
        StoryCard {
            HStack { Text(title).font(.headline); Spacer(); Text("\(selected.wrappedValue.count) / \(count)").font(.caption.monospacedDigit()) }
            ForEach(Array(Set(choices + selected.wrappedValue)).sorted(), id: \.self) { item in
                Toggle(item.capitalized, isOn: Binding(get: { selected.wrappedValue.contains(item) }, set: { on in if on { if !selected.wrappedValue.contains(item) { selected.wrappedValue.append(item) } } else { selected.wrappedValue.removeAll { $0 == item } } }))
                    .disabled(!selected.wrappedValue.contains(item) && selected.wrappedValue.count >= count)
            }
        }
    }
    private func scoreBinding(_ ability: SRD521Ability) -> Binding<Int> { Binding(get: { draft.baseScores[ability, default: 8] }, set: { draft.baseScores[ability] = $0 }) }
    private func allocationButtons(_ ability: SRD521Ability) -> some View {
        let value = draft.baseScores[ability, default: 8]
        let nextCost = (CharacterCreationDraft.pointCosts[value + 1] ?? 1000) - (CharacterCreationDraft.pointCosts[value] ?? 0)
        return HStack(spacing: 12) {
            Button { draft.baseScores[ability] = value - 1 } label: { Image(systemName: "minus.circle") }.disabled(value <= 8).accessibilityLabel("Decrease \(ability.rawValue)").frame(minWidth: 44, minHeight: 44)
            Text(String(value)).font(.title2.monospacedDigit().bold()).frame(minWidth: 28)
            Button { draft.baseScores[ability] = value + 1 } label: { Image(systemName: "plus.circle") }.disabled(value >= 15 || nextCost > draft.pointsRemaining).accessibilityLabel("Increase \(ability.rawValue)").frame(minWidth: 44, minHeight: 44)
        }.buttonStyle(.borderless)
    }
    private func changeBackground(_ background: CharacterBackground) {
        draft.changeBackground(to: background)
    }
    private func signed(_ value: Int) -> String { value >= 0 ? "+\(value)" : String(value) }
    private func abilityDescription(_ ability: SRD521Ability) -> String { switch ability {
    case .strength: "Physical power"; case .dexterity: "Agility and reflexes"; case .constitution: "Endurance and health"; case .intelligence: "Reasoning and knowledge"; case .wisdom: "Awareness and intuition"; case .charisma: "Presence and influence"
    } }
    private var classDescription: String { switch draft.characterClass {
    case .fighter: "Weapon mastery, a Fighting Style and Second Wind. Strength or Dexterity can lead your approach."
    case .rogue: "Four class skills, Expertise and conditional Sneak Attack. Dexterity supports precision and stealth."
    case .wizard: "Intelligence-based magic: three cantrips, six spellbook spells and four prepared spells."
    case .cleric: "Wisdom-based magic, prepared spells and a Divine Order. Your origin defines your relationship to faith."
    } }
    private var speciesDescription: String { switch draft.species {
    case .human: "Choose a skill and an additional Origin feat. Humans also have Resourceful."
    case .dwarf: "Dwarven Toughness adds one hit point at level one; dwarven traits include poison resilience and darkvision."
    case .halfling: "Small, resourceful adventurers whose Luck can reroll a natural 1 on a D20 Test."
    case .orc: "Resilient adventurers with darkvision, Adrenaline Rush and Relentless Endurance."
    } }
}
