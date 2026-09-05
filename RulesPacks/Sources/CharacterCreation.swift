import Foundation

// SRD 5.2.1: creation pp. 20–22; classes pp. 36–37, 47–48, 61–62,
// 77–79; backgrounds/species pp. 83–86; feats pp. 87–88; armor p. 92.
public enum AbilityGenerationMethod: String, CaseIterable, Codable, Sendable { case pointBuy = "27-point buy", standardArray = "Standard array" }
public enum CharacterSpecies: String, CaseIterable, Codable, Sendable { case human = "Human", dwarf = "Dwarf", halfling = "Halfling", orc = "Orc", elf = "Elf", gnome = "Gnome", tiefling = "Tiefling", dragonborn = "Dragonborn" }
public enum CharacterBackground: String, CaseIterable, Codable, Sendable {
    case acolyte = "Acolyte", criminal = "Criminal", sage = "Sage", soldier = "Soldier"
    public var abilities: [SRD521Ability] { switch self {
    case .acolyte: [.intelligence, .wisdom, .charisma]
    case .criminal: [.dexterity, .constitution, .intelligence]
    case .sage: [.constitution, .intelligence, .wisdom]
    case .soldier: [.strength, .dexterity, .constitution]
    } }
    public var skills: [String] { switch self {
    case .acolyte: ["insight", "religion"]
    case .criminal: ["sleight of hand", "stealth"]
    case .sage: ["arcana", "history"]
    case .soldier: ["athletics", "intimidation"]
    } }
    public var feat: String { switch self { case .acolyte: "Magic Initiate (Cleric)"; case .criminal: "Alert"; case .sage: "Magic Initiate (Wizard)"; case .soldier: "Savage Attacker" } }
    public var spellClass: AdventurerClass? { switch self { case .acolyte: .cleric; case .sage: .wizard; default: nil } }
}
public enum StartingEquipmentChoice: String, CaseIterable, Codable, Sendable { case packageA = "Equipment A", packageB = "Equipment B (Fighter)", gold = "Starting gold" }
public enum FighterStyle: String, CaseIterable, Codable, Sendable { case archery = "Archery", defense = "Defense", greatWeaponFighting = "Great Weapon Fighting", twoWeaponFighting = "Two-Weapon Fighting" }
public enum ClericDivineOrder: String, CaseIterable, Codable, Sendable { case protector = "Protector", thaumaturge = "Thaumaturge" }
public enum HumanOriginFeat: String, CaseIterable, Codable, Sendable { case alert = "Alert", skilled = "Skilled", savageAttacker = "Savage Attacker" }
public enum CharacterCreationError: LocalizedError { case invalid([String]); public var errorDescription: String? { switch self { case .invalid(let reasons): reasons.joined(separator: "\n") } } }

/// An editable creation record. Validation is the boundary between a draft and a playable hero.
/// Unimplemented spell/trait choices remain on the record; they are never granted substitute effects.
public struct CharacterCreationDraft: Codable, Hashable, Sendable {
    public static let abilities: [SRD521Ability] = [.strength, .dexterity, .constitution, .intelligence, .wisdom, .charisma]
    public static let pointCosts: [Int: Int] = [8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9]
    public static let standardArray = [15, 14, 13, 12, 10, 8]
    public static let allSkills = ["acrobatics", "animal handling", "arcana", "athletics", "deception", "history", "insight", "intimidation", "investigation", "medicine", "nature", "perception", "performance", "persuasion", "religion", "sleight of hand", "stealth", "survival"]
    public static let standardLanguages = ["Common Sign Language", "Draconic", "Dwarvish", "Elvish", "Giant", "Gnomish", "Goblin", "Halfling", "Orc"]
    public var name = ""
    public var alignment = "Neutral"
    public var appearance = ""
    public var characterClass: AdventurerClass = .fighter
    public var species: CharacterSpecies = .human
    public var background: CharacterBackground = .soldier
    public var method: AbilityGenerationMethod = .pointBuy
    public var baseScores: [SRD521Ability: Int] = Dictionary(uniqueKeysWithValues: Self.abilities.map { ($0, 8) })
    public var backgroundBoosts: [SRD521Ability: Int] = [:]
    public var classSkills: [String] = []
    public var expertise: [String] = []
    public var cantrips: [String] = []
    public var spellbook: [String] = []
    public var preparedSpells: [String] = []
    public var equipmentChoice: StartingEquipmentChoice = .packageA
    public var backgroundEquipmentGold = false
    public var fightingStyle: FighterStyle = .defense
    public var divineOrder: ClericDivineOrder = .protector
    public var humanSkill = "perception"
    public var humanFeat: HumanOriginFeat = .skilled
    public var skilledSkills: [String] = []
    public var humanSmall = false
    public var languages: [String] = ["Dwarvish", "Elvish"]
    public var rogueExtraLanguage = "Orc"
    public var gamingSet = "Dice Set"
    public var masteryWeapons: [String] = []
    public var originCantrips: [String] = []
    public var originSpell = ""
    public var originSpellAbility: SRD521Ability = .wisdom
    public init() {}

    /// Class changes retain the person's identity and allocated scores. Only class-dependent
    /// choices that are no longer legal are replaced, retaining valid selections in their order.
    public mutating func changeClass(to newClass: AdventurerClass) {
        guard characterClass != newClass else { return }
        characterClass = newClass
        if equipmentChoice == .packageB && newClass != .fighter { equipmentChoice = .packageA }
        normalizeDependentSelections()
    }

    /// A different background never reallocates base scores or erases the character's identity.
    public mutating func changeBackground(to newBackground: CharacterBackground) {
        guard background != newBackground else { return }
        background = newBackground
        let current = backgroundBoosts.filter { $0.value != 0 }
        if !Set(current.keys).isSubset(of: Set(background.abilities)) || ![[1, 2], [1, 1, 1]].contains(current.values.sorted()) {
            var legal: [[SRD521Ability: Int]] = []
            for major in background.abilities { for minor in background.abilities where minor != major { legal.append([major: 2, minor: 1]) } }
            legal.append(Dictionary(uniqueKeysWithValues: background.abilities.map { ($0, 1) }))
            func retained(_ option: [SRD521Ability: Int]) -> Int { option.reduce(0) { $0 + (current[$1.key] == $1.value ? 10 : current[$1.key] != nil ? 1 : 0) } }
            backgroundBoosts = legal.enumerated().sorted { retained($0.element) == retained($1.element) ? $0.offset < $1.offset : retained($0.element) > retained($1.element) }[0].element
        }
        normalizeDependentSelections()
    }

    private mutating func normalizeDependentSelections() {
        let defaults = Self.suggested(for: characterClass, name: name)
        func choices(_ current: [String], preferred: [String], allowed: [String], count: Int) -> [String] {
            var result: [String] = []
            for value in current + preferred + allowed where result.count < count && allowed.contains(value) && !result.contains(value) { result.append(value) }
            return result
        }
        let allowedSkills = availableClassSkills.filter { !background.skills.contains($0) }
        // Preserve species/feat skills where possible when filling newly vacant class choices.
        let reserved = species == .human ? [humanSkill] + (humanFeat == .skilled ? skilledSkills : []) : []
        let preferredSkills = defaults.classSkills.filter { !reserved.contains($0) } + allowedSkills.filter { !reserved.contains($0) } + defaults.classSkills
        classSkills = choices(classSkills, preferred: preferredSkills, allowed: allowedSkills, count: requiredClassSkillCount)
        if species == .human {
            let allowedHuman = Self.allSkills.filter { !(background.skills + classSkills).contains($0) }
            humanSkill = choices([humanSkill], preferred: [defaults.humanSkill], allowed: allowedHuman, count: 1)[0]
            if humanFeat.rawValue == background.feat { humanFeat = .skilled }
            if humanFeat == .skilled { skilledSkills = choices(skilledSkills, preferred: defaults.skilledSkills, allowed: allowedHuman.filter { $0 != humanSkill }, count: 3) }
        }
        expertise = characterClass == .rogue ? choices(expertise, preferred: defaults.expertise, allowed: trainedSkills, count: 2) : []
        if characterClass == .rogue && (!Self.standardLanguages.contains(rogueExtraLanguage) || languages.contains(rogueExtraLanguage)) { rogueExtraLanguage = Self.standardLanguages.first { !languages.contains($0) }! }
        cantrips = choices(cantrips, preferred: defaults.cantrips, allowed: availableCantrips, count: requiredCantripCount)
        if characterClass == .wizard {
            spellbook = choices(spellbook, preferred: preparedSpells + defaults.spellbook, allowed: availableLevelOneSpells, count: 6)
            preparedSpells = choices(preparedSpells, preferred: defaults.preparedSpells, allowed: spellbook, count: 4)
        } else {
            spellbook = []
            preparedSpells = choices(preparedSpells, preferred: defaults.preparedSpells, allowed: availableLevelOneSpells, count: Self.requiredPreparedSpells(for: characterClass))
        }
        masteryWeapons = choices(masteryWeapons, preferred: defaults.masteryWeapons, allowed: availableMasteryWeapons, count: characterClass == .fighter ? 3 : characterClass == .rogue ? 2 : 0)
        if let originClass = background.spellClass {
            originCantrips = choices(originCantrips, preferred: originClass == .wizard ? ["mending", "prestidigitation"] : ["light", "mending"], allowed: Self.cantrips(for: originClass), count: 2)
            originSpell = choices([originSpell], preferred: [originClass == .wizard ? "alarm" : "cure wounds"], allowed: Self.levelOneSpells(for: originClass), count: 1)[0]
            if ![.intelligence, .wisdom, .charisma].contains(originSpellAbility) { originSpellAbility = originClass == .wizard ? .intelligence : .wisdom }
        } else { originCantrips = []; originSpell = "" }
    }

    public var pointBuySpent: Int { baseScores.values.reduce(0) { $0 + (Self.pointCosts[$1] ?? 1000) } }
    public var pointsRemaining: Int { 27 - pointBuySpent }
    public var finalScores: [SRD521Ability: Int] { Dictionary(uniqueKeysWithValues: Self.abilities.map { ability in
        let base = baseScores[ability, default: 8], boost = backgroundBoosts[ability, default: 0]
        let sum = base.addingReportingOverflow(boost)
        return (ability, sum.overflow ? (boost > 0 ? Int.max : Int.min) : sum.partialValue)
    }) }
    public func modifier(_ ability: SRD521Ability) -> Int { Int(floor((Double(finalScores[ability, default: 10]) - 10) / 2)) }
    public var requiredClassSkillCount: Int { characterClass == .rogue ? 4 : characterClass == .bard || characterClass == .ranger ? 3 : 2 }
    public var availableClassSkills: [String] { Self.skills(for: characterClass) }
    public var requiredCantripCount: Int { characterClass == .wizard ? 3 : characterClass == .cleric ? (divineOrder == .thaumaturge ? 4 : 3) : characterClass == .sorcerer ? 4 : [.bard, .druid, .warlock].contains(characterClass) ? 2 : 0 }
    public var availableCantrips: [String] { Self.cantrips(for: characterClass) }
    public var availableLevelOneSpells: [String] { Self.levelOneSpells(for: characterClass) }
    public var equippedArmor: String? {
        guard equipmentChoice != .gold else { return nil }
        switch characterClass {
        case .fighter: return equipmentChoice == .packageA ? "Chain Mail" : "Studded Leather Armor"
        case .barbarian, .bard, .druid, .ranger, .rogue, .warlock: return "Leather Armor"
        case .cleric: return "Chain Shirt"
        case .paladin: return "Chain Mail"
        case .wizard, .monk, .sorcerer: return nil
        }
    }
    public var armorClass: Int {
        let dex = modifier(.dexterity)
        let base: Int
        switch equippedArmor { case "Chain Mail": base = 16; case "Studded Leather Armor": base = 12 + dex; case "Leather Armor": base = 11 + dex; case "Chain Shirt": base = 13 + min(2, dex); default: base = 10 + dex }
        return base + (characterClass == .cleric && equipmentChoice == .packageA ? 2 : 0) + (characterClass == .fighter && fightingStyle == .defense && equippedArmor != nil ? 1 : 0)
    }
    public var maximumHitPoints: Int { AdventurerClass.hitDie(for: characterClass) + modifier(.constitution) + (species == .dwarf ? 1 : 0) }
    public var speed: Int { equippedArmor == "Chain Mail" && finalScores[.strength, default: 8] < 13 ? 20 : 30 }
    public var size: String { [.halfling, .gnome].contains(species) || (species == .human && humanSmall) ? "Small" : "Medium" }
    public var savingThrowProficiencies: [SRD521Ability] { switch characterClass {
    case .barbarian: [.strength, .constitution]; case .bard: [.dexterity, .charisma]; case .cleric, .druid, .paladin, .warlock: [.wisdom, .charisma]; case .fighter: [.strength, .constitution]; case .monk, .ranger, .rogue: [.dexterity, .intelligence]; case .sorcerer: [.constitution, .charisma]; case .wizard: [.intelligence, .wisdom]
    } }
    public var trainedSkills: [String] { Array(Set(background.skills + classSkills + (species == .human ? [humanSkill] + (humanFeat == .skilled ? skilledSkills : []) : []))).sorted() }
    public var allLanguages: [String] {
        let ancestryLanguage: String? = switch species { case .elf: "Elvish"; case .gnome: "Gnomish"; case .tiefling: "Infernal"; case .dragonborn: "Draconic"; case .dwarf: "Dwarvish"; case .halfling: "Halfling"; case .orc: "Orc"; case .human: nil }
        return Array(Set(["Common"] + languages + (ancestryLanguage.map { [$0] } ?? []) + (characterClass == .rogue ? ["Thieves’ Cant", rogueExtraLanguage] : []))).sorted()
    }
    public var feats: [String] { [background.feat] + (species == .human ? [humanFeat.rawValue] : []) }
    public var toolProficiencies: [String] {
        let backgroundTool = background == .soldier ? gamingSet : background == .criminal ? "Thieves’ Tools" : "Calligrapher’s Supplies"
        return Array(Set([backgroundTool] + (characterClass == .rogue ? ["Thieves’ Tools"] : []))).sorted()
    }

    public var validationErrors: [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 80 { errors.append("Enter a character name of 1–80 characters.") }
        if !["Lawful Good", "Neutral Good", "Chaotic Good", "Lawful Neutral", "Neutral", "Chaotic Neutral", "Lawful Evil", "Neutral Evil", "Chaotic Evil"].contains(alignment) { errors.append("Choose one of the nine alignments.") }
        if appearance.count > 1500 { errors.append("Keep appearance to 1,500 characters or fewer.") }
        if Set(baseScores.keys) != Set(Self.abilities) || baseScores.values.contains(where: { !(8...15).contains($0) }) { errors.append("Assign all six base ability scores, each from 8 through 15.") }
        if method == .pointBuy && pointBuySpent != 27 { errors.append("Spend exactly 27 ability points (currently \(pointBuySpent)).") }
        if method == .standardArray && baseScores.values.sorted() != Self.standardArray.sorted() { errors.append("Assign each standard-array score exactly once: 15, 14, 13, 12, 10, 8.") }
        let boosts = backgroundBoosts.filter { $0.value != 0 }
        if !Set(boosts.keys).isSubset(of: Set(background.abilities)) || ![[1, 2], [1, 1, 1]].contains(boosts.values.sorted()) || finalScores.values.contains(where: { $0 > 20 }) { errors.append("Background increases must be +2/+1 on different listed abilities, or +1 on all three.") }
        if classSkills.count != requiredClassSkillCount || Set(classSkills).count != classSkills.count || !Set(classSkills).isSubset(of: Set(availableClassSkills)) { errors.append("Choose \(requiredClassSkillCount) distinct skills from your class list.") }
        if !Set(classSkills).isDisjoint(with: Set(background.skills)) { errors.append("Choose class skills that do not duplicate your background proficiencies.") }
        if species == .human {
            if !Self.allSkills.contains(humanSkill) || (background.skills + classSkills).contains(humanSkill) { errors.append("Choose a new skill for Human Skillful.") }
            if humanFeat.rawValue == background.feat { errors.append("That Origin feat is already supplied by your background and is not repeatable.") }
            if humanFeat == .skilled && (skilledSkills.count != 3 || Set(skilledSkills).count != 3 || !Set(skilledSkills).isSubset(of: Set(Self.allSkills)) || !Set(skilledSkills).isDisjoint(with: Set(background.skills + classSkills + [humanSkill]))) { errors.append("Choose three new distinct skills for Skilled.") }
        }
        if characterClass == .rogue {
            if expertise.count != 2 || Set(expertise).count != 2 || !Set(expertise).isSubset(of: Set(trainedSkills)) { errors.append("Choose two proficient skills for Rogue Expertise.") }
            if !Self.standardLanguages.contains(rogueExtraLanguage) || languages.contains(rogueExtraLanguage) { errors.append("Choose a different extra language for Thieves’ Cant.") }
        } else if !expertise.isEmpty { errors.append("Only Rogue has skill Expertise at level one in this rules subset.") }
        if languages.count != 2 || Set(languages).count != 2 || !Set(languages).isSubset(of: Set(Self.standardLanguages)) { errors.append("Choose two different standard languages in addition to Common.") }
        if cantrips.count != requiredCantripCount || Set(cantrips).count != cantrips.count || !Set(cantrips).isSubset(of: Set(availableCantrips)) { errors.append("Choose \(requiredCantripCount) distinct class cantrips.") }
        if characterClass == .wizard {
            if spellbook.count != 6 || Set(spellbook).count != 6 || !Set(spellbook).isSubset(of: Set(availableLevelOneSpells)) { errors.append("Choose six different level-one Wizard spells for your spellbook.") }
            if preparedSpells.count != 4 || Set(preparedSpells).count != 4 || !Set(preparedSpells).isSubset(of: Set(spellbook)) { errors.append("Prepare four different spells from your spellbook.") }
        } else if Self.selectsClassSpells(characterClass) {
            if !spellbook.isEmpty { errors.append("Clerics do not use a Wizard spellbook.") }
            let required = Self.requiredPreparedSpells(for: characterClass)
            if preparedSpells.count != required || Set(preparedSpells).count != required || !Set(preparedSpells).isSubset(of: Set(availableLevelOneSpells)) { errors.append("Choose \(required) different supported level-one \(characterClass.rawValue) spells.") }
        } else if !spellbook.isEmpty || !preparedSpells.isEmpty { errors.append("This class has no supported class spellcasting at level one.") }
        if let originClass = background.spellClass {
            if originCantrips.count != 2 || Set(originCantrips).count != 2 || !Set(originCantrips).isSubset(of: Set(Self.cantrips(for: originClass))) || !Self.levelOneSpells(for: originClass).contains(originSpell) || ![.intelligence, .wisdom, .charisma].contains(originSpellAbility) { errors.append("Magic Initiate needs two cantrips, one level-one spell from its class list, and INT, WIS, or CHA.") }
        } else if !originCantrips.isEmpty || !originSpell.isEmpty { errors.append("This background does not grant Magic Initiate.") }
        if equipmentChoice == .packageB && characterClass != .fighter { errors.append("Only Fighter has a second equipment package; other classes may choose their package or gold.") }
        let masteryCount = characterClass == .fighter ? 3 : characterClass == .rogue ? 2 : 0
        if masteryWeapons.count != masteryCount || Set(masteryWeapons).count != masteryCount || !Set(masteryWeapons).isSubset(of: Set(availableMasteryWeapons)) { errors.append("Choose \(masteryCount) different proficient weapon kinds for Weapon Mastery.") }
        if background == .soldier && !["Dice Set", "Dragonchess Set", "Playing Card Set", "Three-Dragon Ante Set"].contains(gamingSet) { errors.append("Choose a supported Gaming Set.") }
        return errors
    }

    public func build() throws -> OpenWorldHero {
        let errors = validationErrors
        guard errors.isEmpty else { throw CharacterCreationError.invalid(errors) }
        var hero = OpenWorldHero(name: name.trimmingCharacters(in: .whitespacesAndNewlines), characterClass: characterClass, scores: finalScores, skills: Dictionary(uniqueKeysWithValues: trainedSkills.map { ($0, expertise.contains($0) ? 4 : 2) }), hitPoints: maximumHitPoints, maximumHitPoints: maximumHitPoints, armorClass: armorClass, spellSlots: characterClass == .warlock ? 1 : AdventurerClass.levelOneSpellcasters.contains(characterClass) ? 2 : 0, secondWindUses: characterClass == .fighter ? 2 : 0, weapons: startingWeapons, spells: cantrips + preparedSpells, equipment: startingEquipment)
        hero.spellbook = characterClass == .wizard ? spellbook : nil
        if background.spellClass != nil { hero.magicInitiate = .init(cantrips: originCantrips, spell: originSpell, ability: originSpellAbility) }
        hero.creation = self
        hero.classFeatures = .initial(for: characterClass, charismaModifier: hero.modifier(.charisma))
        return hero
    }

    public var manualAdjudicationNotes: [String] {
        var notes = ["Creation includes deterministic level-one class resources and only the supported spell catalog. Traits outside a listed engine receipt remain intentionally ungranted."]
        if feats.contains("Alert") { notes.append("Alert initiative proficiency and initiative swap require adjudication; the open-world engine does not track initiative.") }
        notes.append("Spell choices are limited to the implemented catalog. Ritual casting and spellbook preparation changes require separate support.")
        if species == .human { notes.append("Human Heroic Inspiration requires adjudication. Selected Skillful and Skilled skill proficiencies are included.") }
        if species == .dwarf { notes.append("Dwarven Toughness +1 HP is included; poison resilience, darkvision, and Stonecunning require adjudication.") }
        if species == .halfling { notes.append("Halfling Luck is applied to player d20 tests. Brave, Nimbleness, and Naturally Stealthy require adjudication.") }
        if species == .orc { notes.append("Orc Adrenaline Rush, darkvision, and Relentless Endurance require adjudication.") }
        if species == .elf { notes.append("Elf identity and Elvish persist; unimplemented sensory and trance effects are not silently applied.") }
        if species == .gnome { notes.append("Gnome identity, Small size and Gnomish persist; no unimplemented magical resistance is granted.") }
        if species == .tiefling { notes.append("Tiefling identity and Infernal persist; unimplemented legacy magic and resistance are not granted.") }
        if species == .dragonborn { notes.append("Dragonborn identity and Draconic persist; breath weapon and resistance await a dedicated resolver.") }
        if characterClass == .fighter && fightingStyle == .twoWeaponFighting { notes.append("Two-Weapon Fighting is selected; extra Light-weapon attacks require adjudication.") }
        if !masteryWeapons.isEmpty { notes.append("Weapon Mastery choices are recorded; mastery effects require adjudication.") }
        return notes
    }

    public var contextDescription: String {
        let scores = Self.abilities.map { "\($0.rawValue) \(finalScores[$0, default: 8])" }.joined(separator: ", ")
        var lines = ["\(name): \(species.rawValue), \(size), level 1 \(characterClass.rawValue), \(background.rawValue) background, \(alignment).", "Appearance: \(appearance.isEmpty ? "not supplied" : appearance).", "Abilities: \(scores). Speed \(speed) ft. Saving throw proficiencies: \(savingThrowProficiencies.map(\.rawValue).joined(separator: ", ")).", "Languages: \(allLanguages.joined(separator: ", ")). Tools: \(toolProficiencies.joined(separator: ", ")). Feats: \(feats.joined(separator: ", "))."]
        if characterClass == .fighter { lines.append("Fighting Style: \(fightingStyle.rawValue).") }
        if characterClass == .cleric { lines.append("Divine Order: \(divineOrder.rawValue).") }
        if !expertise.isEmpty { lines.append("Expertise: \(expertise.joined(separator: ", ")).") }
        if !masteryWeapons.isEmpty { lines.append("Weapon Mastery selections: \(masteryWeapons.joined(separator: ", ")).") }
        if !spellbook.isEmpty { lines.append("Spellbook: \(spellbook.joined(separator: ", ")); prepared: \(preparedSpells.joined(separator: ", ")).") }
        if background.spellClass != nil { lines.append("Magic Initiate (\(originSpellAbility.rawValue)): \(originCantrips.joined(separator: ", ")); \(originSpell).") }
        lines.append("Do not invent unchosen features, ancestry abilities, possessions, appearance, or motivations. Follow engine receipts for mechanical effects.")
        return lines.joined(separator: "\n")
    }

    public static func skills(for cls: AdventurerClass) -> [String] { switch cls {
    case .barbarian: ["animal handling", "athletics", "intimidation", "nature", "perception", "survival"]
    case .bard: ["acrobatics", "animal handling", "arcana", "athletics", "deception", "history", "insight", "intimidation", "investigation", "medicine", "nature", "perception", "performance", "persuasion", "religion", "sleight of hand", "stealth", "survival"]
    case .fighter: ["acrobatics", "animal handling", "athletics", "history", "insight", "intimidation", "persuasion", "perception", "survival"]
    case .rogue: ["acrobatics", "athletics", "deception", "insight", "intimidation", "investigation", "perception", "persuasion", "sleight of hand", "stealth"]
    case .wizard: ["arcana", "history", "insight", "investigation", "medicine", "nature", "religion"]
    case .cleric: ["history", "insight", "medicine", "persuasion", "religion"]
    case .druid: ["arcana", "animal handling", "insight", "medicine", "nature", "perception", "religion", "survival"]
    case .monk: ["acrobatics", "athletics", "history", "insight", "religion", "stealth"]
    case .paladin: ["athletics", "insight", "intimidation", "medicine", "persuasion", "religion"]
    case .ranger: ["animal handling", "athletics", "insight", "investigation", "nature", "perception", "stealth", "survival"]
    case .sorcerer: ["arcana", "deception", "insight", "intimidation", "persuasion", "religion"]
    case .warlock: ["arcana", "deception", "history", "intimidation", "investigation", "nature", "religion"]
    } }
    public static func cantrips(for cls: AdventurerClass) -> [String] { CreationSpellCatalog.cantrips(for: cls) }
    public static func levelOneSpells(for cls: AdventurerClass) -> [String] { CreationSpellCatalog.levelOneSpells(for: cls) }
    public var availableMasteryWeapons: [String] {
        let simple = ["club", "dagger", "greatclub", "handaxe", "javelin", "light hammer", "mace", "quarterstaff", "sickle", "spear", "dart", "light crossbow", "shortbow", "sling"]
        if characterClass == .fighter { return (simple + ["battleaxe", "flail", "glaive", "greataxe", "greatsword", "halberd", "lance", "longsword", "maul", "morningstar", "pike", "rapier", "scimitar", "shortsword", "trident", "warhammer", "war pick", "whip", "blowgun", "hand crossbow", "heavy crossbow", "longbow"]).sorted() }
        return characterClass == .rogue ? (simple + ["rapier", "scimitar", "shortsword", "whip", "hand crossbow"]).sorted() : []
    }
    public var startingWeapons: [String] {
        var weapons: [String] = []
        if equipmentChoice != .gold { switch characterClass {
        case .fighter: weapons = equipmentChoice == .packageA ? ["greatsword", "flail", "javelin"] : ["scimitar", "shortsword", "longbow"]
        case .rogue: weapons = ["dagger", "shortsword", "shortbow"]
        case .wizard: weapons = ["dagger", "quarterstaff"]
        case .cleric: weapons = ["mace"]
        case .barbarian: weapons = ["greatsword", "javelin"]
        case .bard: weapons = ["shortsword", "dagger"]
        case .druid: weapons = ["quarterstaff", "scimitar"]
        case .monk: weapons = ["quarterstaff", "dagger"]
        case .paladin: weapons = ["longsword", "javelin"]
        case .ranger: weapons = ["shortsword", "longbow"]
        case .sorcerer: weapons = ["dagger"]
        case .warlock: weapons = ["dagger", "shortbow"]
        } }
        if !backgroundEquipmentGold { switch background { case .criminal: weapons += ["dagger"]; case .sage: weapons += ["quarterstaff"]; case .soldier: weapons += ["spear", "shortbow"]; case .acolyte: break } }
        return Array(Set(weapons)).sorted()
    }
    public var startingEquipment: [String] {
        var items: [String]
        if equipmentChoice == .gold { items = ["\(characterClass == .fighter ? 155 : characterClass == .rogue ? 100 : characterClass == .wizard ? 55 : 110) GP (class)"] }
        else { switch characterClass {
        case .fighter: items = equipmentChoice == .packageA ? ["Chain Mail", "Greatsword", "Flail", "8 Javelins", "Dungeoneer’s Pack", "4 GP (class)"] : ["Studded Leather Armor", "Scimitar", "Shortsword", "Longbow", "20 Arrows", "Quiver", "Dungeoneer’s Pack", "11 GP (class)"]
        case .rogue: items = ["Leather Armor", "2 Daggers", "Shortsword", "Shortbow", "20 Arrows", "Quiver", "Thieves’ Tools", "Burglar’s Pack", "8 GP (class)"]
        case .wizard: items = ["2 Daggers", "Arcane Focus (Quarterstaff)", "Robe", "Spellbook", "Scholar’s Pack", "5 GP (class)"]
        case .cleric: items = ["Chain Shirt", "Shield", "Mace", "Holy Symbol", "Priest’s Pack", "7 GP (class)"]
        case .barbarian: items = ["Greatsword", "4 Javelins", "Explorer’s Pack", "15 GP (class)"]
        case .bard: items = ["Leather Armor", "Shortsword", "Dagger", "Musical Instrument", "Entertainer’s Pack", "19 GP (class)"]
        case .druid: items = ["Leather Armor", "Shield", "Scimitar", "Druidic Focus", "Explorer’s Pack", "9 GP (class)"]
        case .monk: items = ["Quarterstaff", "2 Daggers", "Explorer’s Pack", "11 GP (class)"]
        case .paladin: items = ["Chain Mail", "Longsword", "Shield", "Holy Symbol", "Priest’s Pack", "9 GP (class)"]
        case .ranger: items = ["Studded Leather Armor", "Shortsword", "Longbow", "20 Arrows", "Explorer’s Pack", "7 GP (class)"]
        case .sorcerer: items = ["2 Daggers", "Arcane Focus", "Explorer’s Pack", "28 GP (class)"]
        case .warlock: items = ["Leather Armor", "Dagger", "Arcane Focus", "Scholar’s Pack", "15 GP (class)"]
        } }
        if backgroundEquipmentGold { return items + ["50 GP (background)"] }
        switch background {
        case .acolyte: items += ["Calligrapher’s Supplies", "Book (prayers)", "Holy Symbol", "10 sheets of Parchment", "Robe", "8 GP (background)"]
        case .criminal: items += ["2 Daggers", "Thieves’ Tools", "Crowbar", "2 Pouches", "Traveler’s Clothes", "16 GP (background)"]
        case .sage: items += ["Quarterstaff", "Calligrapher’s Supplies", "Book (history)", "8 sheets of Parchment", "Robe", "8 GP (background)"]
        case .soldier: items += ["Spear", "Shortbow", "20 Arrows", gamingSet, "Healer’s Kit", "Quiver", "Traveler’s Clothes", "14 GP (background)"]
        }
        return items
    }

    public static func suggested(for cls: AdventurerClass, name: String = "") -> Self {
        var draft = Self(); draft.name = name; draft.characterClass = cls
        draft.background = cls == .fighter || cls == .barbarian || cls == .monk || cls == .paladin || cls == .ranger ? .soldier : cls == .rogue ? .criminal : cls == .wizard || cls == .sorcerer || cls == .warlock ? .sage : .acolyte
        draft.method = .standardArray
        let scores: [Int] = cls == .barbarian ? [15, 13, 14, 8, 12, 10] : cls == .bard || cls == .sorcerer || cls == .warlock ? [8, 14, 13, 10, 12, 15] : cls == .druid ? [10, 14, 13, 8, 15, 12] : cls == .monk ? [10, 15, 13, 8, 14, 12] : cls == .paladin ? [15, 10, 13, 8, 12, 14] : cls == .ranger ? [12, 15, 13, 8, 14, 10] : cls == .fighter ? [15, 14, 13, 8, 10, 12] : cls == .rogue ? [12, 15, 13, 14, 10, 8] : cls == .wizard ? [8, 12, 13, 15, 14, 10] : [14, 8, 13, 10, 15, 12]
        draft.baseScores = Dictionary(uniqueKeysWithValues: zip(Self.abilities, scores))
        draft.backgroundBoosts = cls == .fighter || cls == .barbarian || cls == .paladin ? [.strength: 2, .constitution: 1] : cls == .rogue || cls == .monk || cls == .ranger ? [.dexterity: 2, .constitution: 1] : cls == .wizard || cls == .sorcerer || cls == .warlock ? [.intelligence: 2, .constitution: 1] : [.wisdom: 2, .charisma: 1]
        draft.classSkills = Array(draft.availableClassSkills.filter { !draft.background.skills.contains($0) }.prefix(draft.requiredClassSkillCount))
        draft.humanSkill = Self.allSkills.first { !(draft.background.skills + draft.classSkills).contains($0) }!
        draft.skilledSkills = Array(Self.allSkills.filter { !(draft.background.skills + draft.classSkills + [draft.humanSkill]).contains($0) }.prefix(3))
        if cls == .rogue { draft.expertise = ["sleight of hand", "stealth"] }
        if cls == .wizard { draft.cantrips = ["fire bolt", "light", "mage hand"]; draft.spellbook = ["detect magic", "comprehend languages", "disguise self", "magic missile", "unseen servant", "alarm"]; draft.preparedSpells = ["detect magic", "disguise self", "magic missile", "comprehend languages"] }
        if cls == .cleric { draft.cantrips = ["light", "sacred flame", "thaumaturgy"]; draft.preparedSpells = ["detect magic", "cure wounds", "guiding bolt", "healing word"] }
        if [.bard, .druid, .sorcerer, .warlock].contains(cls) { draft.cantrips = Array(draft.availableCantrips.prefix(draft.requiredCantripCount)) }
        if Self.selectsClassSpells(cls) { draft.preparedSpells = Array(draft.availableLevelOneSpells.prefix(Self.requiredPreparedSpells(for: cls))) }
        if cls == .fighter { draft.masteryWeapons = ["greatsword", "flail", "javelin"] }
        if cls == .rogue { draft.masteryWeapons = ["shortsword", "shortbow"] }
        if let origin = draft.background.spellClass { draft.originCantrips = origin == .wizard ? ["mending", "prestidigitation"] : ["light", "mending"]; draft.originSpell = origin == .wizard ? "alarm" : "cure wounds"; draft.originSpellAbility = origin == .wizard ? .intelligence : .wisdom }
        return draft
    }

    public static func selectsClassSpells(_ cls: AdventurerClass) -> Bool { [.bard, .cleric, .druid, .paladin, .ranger, .sorcerer, .warlock].contains(cls) }
    public static func preparesSpells(_ cls: AdventurerClass) -> Bool { [.cleric, .druid, .paladin, .ranger].contains(cls) }
    public static func requiredPreparedSpells(for cls: AdventurerClass) -> Int {
        switch cls { case .bard: 4; case .cleric, .druid: 4; case .paladin, .ranger, .sorcerer, .warlock: 2; default: 0 }
    }
}

public extension OpenWorldHero {
    var spellcastingAbility: SRD521Ability? { switch characterClass { case .wizard: .intelligence; case .cleric, .druid, .ranger: .wisdom; case .bard, .paladin, .sorcerer, .warlock: .charisma; default: nil } }
    var spellAttackModifier: Int? { spellcastingAbility.map { proficiencyBonus + modifier($0) } }
    var spellSaveDC: Int? { spellAttackModifier.map { 8 + $0 } }
}
