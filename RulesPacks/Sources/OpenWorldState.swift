import AetherTableCore
import Foundation

public enum AdventurerClass: String, CaseIterable, Codable, Sendable {
    case barbarian = "Barbarian", bard = "Bard", cleric = "Cleric", druid = "Druid", fighter = "Fighter", monk = "Monk", paladin = "Paladin", ranger = "Ranger", rogue = "Rogue", sorcerer = "Sorcerer", warlock = "Warlock", wizard = "Wizard"
}

/// Level-one class state. Optional on the hero so pre-expansion saves decode unchanged.
public struct ClassFeatureState: Codable, Hashable, Sendable {
    public var rageUses: Int = 0
    public var huntersMarkUses: Int = 0
    public var layOnHandsPool: Int = 0
    public var bardicInspirationUses: Int = 0
    public var innateSorceryUses: Int = 0
    public var rageActive: Bool = false
    public var innateSorceryActive: Bool = false
    public var markedTarget: String? = nil
    public var bardicInspirationTarget: String? = nil
    public init() {}
    public static func initial(for characterClass: AdventurerClass, charismaModifier: Int = 0) -> Self {
        var state = Self()
        switch characterClass {
        case .barbarian: state.rageUses = 2
        case .bard: state.bardicInspirationUses = max(1, charismaModifier)
        case .paladin: state.layOnHandsPool = 5
        case .ranger: state.huntersMarkUses = 2
        case .sorcerer: state.innateSorceryUses = 2
        default: break
        }
        return state
    }
    public mutating func recoverLongRest(for characterClass: AdventurerClass, charismaModifier: Int) { self = .initial(for: characterClass, charismaModifier: charismaModifier) }
}
public struct OpenWorldHero: Codable, Hashable, Sendable {
    public var name: String
    public var characterClass: AdventurerClass
    public var scores: [SRD521Ability: Int]
    public var skills: [String: Int]
    public var hitPoints: Int
    public var maximumHitPoints: Int
    public var armorClass: Int
    public var spellSlots: Int
    public var secondWindUses: Int
    public var weapons: [String]
    public var spells: [String]
    public var equipment: [String]
    public var level: Int = 1
    public var creation: CharacterCreationDraft? = nil
    public var spellbook: [String]? = nil
    public var magicInitiate: MagicInitiateGrant? = nil
    public var activeUtilitySpells: [String: String]? = nil
    public var concentratingOn: String? = nil
    public var classFeatures: ClassFeatureState? = nil
    public var proficiencyBonus: Int { 2 }
    public static let supportedWeapons: Set<String> = ["greatsword", "longsword", "shortsword", "shortbow", "quarterstaff", "mace", "flail", "javelin", "scimitar", "longbow", "dagger", "spear"]
    public static func weaponKey(for equipment: String) -> String? {
        let name = equipment.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if supportedWeapons.contains(name) { return name }
        if name == "arcane focus (quarterstaff)" { return "quarterstaff" }
        let parts = name.split(separator: " ", maxSplits: 1)
        if parts.count == 2, Int(parts[0]) != nil {
            let singular = String(parts[1].hasSuffix("s") ? parts[1].dropLast() : parts[1])
            if supportedWeapons.contains(singular) { return singular }
        }
        return nil
    }
    public func isProficient(with weapon: String) -> Bool {
        switch characterClass {
        case .fighter, .barbarian, .paladin, .ranger: return true
        case .cleric: return creation?.divineOrder == .protector || ["quarterstaff", "mace", "dagger", "javelin", "spear"].contains(weapon)
        case .rogue: return ["quarterstaff", "mace", "dagger", "javelin", "spear", "shortbow", "shortsword", "scimitar"].contains(weapon)
        case .monk: return ["quarterstaff", "dagger", "javelin", "spear", "shortbow"].contains(weapon)
        default: return ["quarterstaff", "mace", "dagger", "javelin", "spear", "shortbow"].contains(weapon)
        }
    }
    public func modifier(_ ability: SRD521Ability) -> Int { Int(floor(Double(scores[ability, default: 10] - 10) / 2)) }
    public static func preset(_ characterClass: AdventurerClass, name: String) -> Self {
        let scores: [SRD521Ability: Int]
        let hp: Int, ac: Int
        let skills: [String: Int], weapons: [String], spells: [String], equipment: [String]
        switch characterClass {
        case .barbarian:
            scores = [.strength: 17, .dexterity: 13, .constitution: 16, .intelligence: 8, .wisdom: 10, .charisma: 10]; hp = 14; ac = 14
            skills = ["athletics": 2, "survival": 2]; weapons = ["greatsword", "javelin"]; spells = []; equipment = ["Greatsword", "4 Javelins", "Explorer’s Pack"]
        case .bard:
            scores = [.strength: 8, .dexterity: 14, .constitution: 13, .intelligence: 10, .wisdom: 12, .charisma: 17]; hp = 9; ac = 12
            skills = ["performance": 2, "persuasion": 2, "insight": 2]; weapons = ["shortsword", "dagger"]; spells = ["light", "mending", "healing word", "detect magic"]; equipment = ["Shortsword", "Dagger", "Musical Instrument", "Leather Armor", "Entertainer’s Pack"]
        case .fighter:
            scores = [.strength: 17, .dexterity: 14, .constitution: 14, .intelligence: 8, .wisdom: 10, .charisma: 12]; hp = 12; ac = 17
            skills = ["athletics": 2, "perception": 2]; weapons = ["greatsword"]; spells = []; equipment = ["Greatsword", "Chain mail", "Travel pack"]
        case .rogue:
            scores = [.strength: 12, .dexterity: 17, .constitution: 14, .intelligence: 14, .wisdom: 10, .charisma: 8]; hp = 10; ac = 14
            skills = ["stealth": 4, "sleight of hand": 4, "acrobatics": 2, "investigation": 2]; weapons = ["shortsword", "shortbow"]; spells = []; equipment = ["Shortsword", "Shortbow", "Quiver of arrows", "Leather armor", "Thieves’ tools", "Travel pack"]
        case .wizard:
            scores = [.strength: 8, .dexterity: 12, .constitution: 14, .intelligence: 17, .wisdom: 14, .charisma: 10]; hp = 8; ac = 11
            skills = ["arcana": 2, "history": 2]; weapons = ["quarterstaff"]; spells = ["fire bolt", "mage hand", "light", "magic missile"]; equipment = ["Quarterstaff", "Spellbook", "Arcane focus", "Travel pack"]
        case .cleric:
            scores = [.strength: 13, .dexterity: 12, .constitution: 14, .intelligence: 10, .wisdom: 17, .charisma: 9]; hp = 10; ac = 16
            skills = ["insight": 2, "religion": 2]; weapons = ["mace"]; spells = ["sacred flame", "light", "cure wounds", "healing word", "guiding bolt"]; equipment = ["Mace", "Chain shirt", "Shield", "Holy symbol", "Travel pack"]
        case .druid:
            scores = [.strength: 10, .dexterity: 14, .constitution: 14, .intelligence: 10, .wisdom: 17, .charisma: 8]; hp = 10; ac = 14
            skills = ["nature": 2, "survival": 2]; weapons = ["quarterstaff", "scimitar"]; spells = ["light", "mending", "cure wounds", "detect magic"]; equipment = ["Quarterstaff", "Scimitar", "Leather Armor", "Druidic Focus", "Explorer’s Pack"]
        case .monk:
            scores = [.strength: 10, .dexterity: 17, .constitution: 14, .intelligence: 10, .wisdom: 14, .charisma: 8]; hp = 10; ac = 15
            skills = ["acrobatics": 2, "insight": 2]; weapons = ["quarterstaff", "dagger"]; spells = []; equipment = ["Quarterstaff", "2 Daggers", "Explorer’s Pack"]
        case .paladin:
            scores = [.strength: 17, .dexterity: 10, .constitution: 14, .intelligence: 8, .wisdom: 10, .charisma: 14]; hp = 12; ac = 16
            skills = ["athletics": 2, "persuasion": 2]; weapons = ["longsword", "javelin"]; spells = ["cure wounds", "detect magic"]; equipment = ["Chain Mail", "Longsword", "Shield", "Holy Symbol", "Priest’s Pack"]
        case .ranger:
            scores = [.strength: 12, .dexterity: 17, .constitution: 14, .intelligence: 10, .wisdom: 14, .charisma: 8]; hp = 12; ac = 15
            skills = ["survival": 2, "perception": 2]; weapons = ["shortsword", "longbow"]; spells = ["cure wounds", "detect magic"]; equipment = ["Studded Leather Armor", "Shortsword", "Longbow", "20 Arrows", "Explorer’s Pack"]
        case .sorcerer:
            scores = [.strength: 8, .dexterity: 14, .constitution: 14, .intelligence: 10, .wisdom: 10, .charisma: 17]; hp = 8; ac = 12
            skills = ["arcana": 2, "persuasion": 2]; weapons = ["dagger"]; spells = ["fire bolt", "light", "mage hand", "magic missile", "detect magic"]; equipment = ["2 Daggers", "Arcane Focus", "Explorer’s Pack"]
        case .warlock:
            scores = [.strength: 8, .dexterity: 14, .constitution: 14, .intelligence: 10, .wisdom: 10, .charisma: 17]; hp = 10; ac = 12
            skills = ["arcana": 2, "deception": 2]; weapons = ["dagger", "shortbow"]; spells = ["fire bolt", "mage hand", "magic missile", "detect magic"]; equipment = ["Dagger", "Arcane Focus", "Leather Armor", "Scholar’s Pack"]
        }
        var hero = Self(name: name.trimmingCharacters(in: .whitespacesAndNewlines), characterClass: characterClass, scores: scores, skills: skills, hitPoints: hp, maximumHitPoints: hp, armorClass: ac, spellSlots: characterClass == .warlock ? 1 : AdventurerClass.levelOneSpellcasters.contains(characterClass) ? 2 : 0, secondWindUses: characterClass == .fighter ? 2 : 0, weapons: weapons, spells: spells, equipment: equipment)
        hero.classFeatures = .initial(for: characterClass, charismaModifier: hero.modifier(.charisma))
        return hero
    }
}

public extension AdventurerClass {
    static let levelOneSpellcasters: Set<AdventurerClass> = [.bard, .cleric, .druid, .paladin, .ranger, .sorcerer, .warlock, .wizard]
    var hitDie: Int { switch self { case .barbarian: 12; case .fighter, .paladin, .ranger: 10; case .bard, .cleric, .druid, .monk, .rogue, .warlock: 8; case .sorcerer, .wizard: 6 } }
    static func hitDie(for characterClass: AdventurerClass) -> Int { characterClass.hitDie }
}
public struct WorldMemory: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var category: String
    public var name: String
    public var detail: String
    public var status: String
    public init(id: String, category: String, name: String, detail: String, status: String = "active") { self.id = id; self.category = category; self.name = name; self.detail = detail; self.status = status }
}

/// The player-authored briefing that establishes the first scene.  It is saved
/// with the campaign rather than being a one-time prompt passed to the model.
public struct AdventureOpening: Codable, Hashable, Sendable {
    public var place: String
    public var activity: String
    public var companions: String
    public var reason: String
    public var premise: String

    public init(place: String = "Emberwake, a riverside town", activity: String = "arriving at the river market", companions: String = "alone", reason: String = "to learn why the river is flowing upstream", premise: String = "Something old beneath the town has disturbed the river, and the first people to notice are beginning to disappear.") {
        self.place = place; self.activity = activity; self.companions = companions; self.reason = reason; self.premise = premise
    }

    public static let `default` = AdventureOpening()
    public var isValid: Bool { [place, activity, companions, reason, premise].allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.count <= 800 } }
    public var briefing: String {
        "You are in \(place), \(activity). You are with \(companions). You came here \(reason). Campaign premise: \(premise)"
    }
}
public struct AdventureMessage: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var role: String
    public var text: String
    public var createdAt: Date
    public var receipt: String?
    public init(id: UUID = UUID(), role: String, text: String, receipt: String? = nil) { self.id = id; self.role = role; self.text = text; self.createdAt = .now; self.receipt = receipt }
}
public struct WorldOpponent: Codable, Hashable, Sendable {
    public var name: String
    public var armorClass: Int
    public var hitPoints: Int
    public var maximumHitPoints: Int
    public var saveModifier: Int = 0
    public var attackBonus: Int = 2
    public var damageSides: Int = 6
    public var hostile: Bool = false
    public init(name: String, armorClass: Int, hitPoints: Int, maximumHitPoints: Int, saveModifier: Int = 0, attackBonus: Int = 2, damageSides: Int = 6, hostile: Bool = false) {
        self.name = name; self.armorClass = armorClass; self.hitPoints = hitPoints; self.maximumHitPoints = maximumHitPoints; self.saveModifier = saveModifier; self.attackBonus = attackBonus; self.damageSides = damageSides; self.hostile = hostile
    }
}
public struct OpenWorldAdventure: Codable, Hashable, Sendable {
    public static let key = "open-world.v1"
    public var version = 1
    public var hero: OpenWorldHero
    /// Authored once at creation. Nil means no origin was supplied, not permission to invent one.
    public let creationBackstory: String?
    /// Fixed at creation, this tells the GM how the first scene begins.
    public var opening: AdventureOpening
    public var lastPlayedAt: Date
    public var location: String
    public var transcript: [AdventureMessage]
    public var memories: [WorldMemory]
    public var opponents: [String: WorldOpponent]
    public var turn: Int
    public var guidingBoltTarget: String?
    public var guidingBoltExpires: Int?
    public var rests: Int
    public var hitDieSpent: Bool?
    public var arcaneRecoverySpent: Bool?
    public init(hero: OpenWorldHero, creationBackstory: String? = nil, opening: AdventureOpening = .default) {
        self.creationBackstory = creationBackstory
        self.opening = opening; lastPlayedAt = .now
        self.hero = hero; location = opening.place; transcript = []; opponents = [:]; turn = 0; rests = 0
        memories = [.init(id: "place.opening", category: "place", name: opening.place, detail: "The adventure begins here: \(opening.activity).")]
        memories.append(.init(id: "opening.premise", category: "fact", name: "Campaign premise", detail: opening.premise))
        memories.append(.init(id: "opening.reason", category: "fact", name: "Why \(hero.name) is here", detail: opening.reason))
        if opening.companions.lowercased() != "alone" { memories.append(.init(id: "opening.companions", category: "person", name: "Opening companions", detail: opening.companions)) }
        if let creationBackstory, !creationBackstory.isEmpty { memories.append(.init(id: "hero.background", category: "fact", name: "\(hero.name)’s creation backstory", detail: creationBackstory)) }
        seedInventoryMemories()
    }
    private enum CodingKeys: String, CodingKey {
        case version, hero, creationBackstory, opening, lastPlayedAt, location, transcript, memories, opponents, turn, guidingBoltTarget, guidingBoltExpires, rests, hitDieSpent, arcaneRecoverySpent
    }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        hero = try values.decode(OpenWorldHero.self, forKey: .hero)
        opening = try values.decodeIfPresent(AdventureOpening.self, forKey: .opening) ?? .default
        lastPlayedAt = try values.decodeIfPresent(Date.self, forKey: .lastPlayedAt) ?? .now
        location = try values.decode(String.self, forKey: .location)
        transcript = try values.decode([AdventureMessage].self, forKey: .transcript)
        memories = try values.decode([WorldMemory].self, forKey: .memories)
        if values.contains(.creationBackstory) { creationBackstory = try values.decodeIfPresent(String.self, forKey: .creationBackstory) }
        else { creationBackstory = memories.first(where: { $0.id == "hero.background" })?.detail }
        opponents = try values.decode([String: WorldOpponent].self, forKey: .opponents)
        turn = try values.decode(Int.self, forKey: .turn)
        guidingBoltTarget = try values.decodeIfPresent(String.self, forKey: .guidingBoltTarget)
        guidingBoltExpires = try values.decodeIfPresent(Int.self, forKey: .guidingBoltExpires)
        rests = try values.decode(Int.self, forKey: .rests)
        hitDieSpent = try values.decodeIfPresent(Bool.self, forKey: .hitDieSpent)
        arcaneRecoverySpent = try values.decodeIfPresent(Bool.self, forKey: .arcaneRecoverySpent)
    }
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version); try values.encode(hero, forKey: .hero)
        // Explicit null distinguishes a newly created unspecified origin from an older save needing migration.
        try values.encode(creationBackstory, forKey: .creationBackstory)
        try values.encode(opening, forKey: .opening); try values.encode(lastPlayedAt, forKey: .lastPlayedAt)
        try values.encode(location, forKey: .location); try values.encode(transcript, forKey: .transcript)
        try values.encode(memories, forKey: .memories); try values.encode(opponents, forKey: .opponents)
        try values.encode(turn, forKey: .turn); try values.encode(rests, forKey: .rests)
        try values.encodeIfPresent(guidingBoltTarget, forKey: .guidingBoltTarget)
        try values.encodeIfPresent(guidingBoltExpires, forKey: .guidingBoltExpires)
        try values.encodeIfPresent(hitDieSpent, forKey: .hitDieSpent)
        try values.encodeIfPresent(arcaneRecoverySpent, forKey: .arcaneRecoverySpent)
    }
    public func validateOriginMemoryUpdates(_ updates: [WorldMemory]) throws {
        for update in updates {
            let id = update.id.lowercased()
            let reserved = ["hero.background", "hero.backstory", "hero.origin", "legacy.character"].contains(id) || id.hasPrefix("hero.background.") || id.hasPrefix("hero.backstory.") || id.hasPrefix("hero.origin.")
            if reserved && !memories.contains(update) { throw OpenWorldError.invalidPlan("The GM tried to change your creation backstory. Your origins are fixed; only relationships earned during play may develop. Retry the turn.") }
        }
    }
    private mutating func seedInventoryMemories() {
        for item in hero.equipment where !memories.contains(where: { $0.category == "inventory" && $0.name.caseInsensitiveCompare(item) == .orderedSame }) {
            let slug = item.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).joined(separator: ".")
            let candidateID = "inventory.carried." + String(slug.prefix(60))
            let id = memories.contains(where: { $0.id == candidateID }) ? "inventory.carried.\(UUID().uuidString)" : candidateID
            memories.append(.init(id: id, category: "inventory", name: item, detail: "Carried by \(hero.name)."))
        }
    }
    /// Apply validated possession changes before replacing the matching memory records.
    /// Incidental items never grant unimplemented weapon mechanics or alter armor/statistics.
    public mutating func reconcileInventory(_ updates: [WorldMemory]) {
        for update in updates where update.category == "inventory" {
            let previousName = memories.first(where: { $0.id == update.id && $0.category == "inventory" })?.name
            let names = [previousName, update.name].compactMap { $0 }.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            hero.equipment.removeAll { names.contains($0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)) }
            let weaponNames = names.compactMap { OpenWorldHero.weaponKey(for: $0) }
            hero.weapons.removeAll { weaponNames.contains($0.lowercased()) }
            if update.status == "active" {
                hero.equipment.append(update.name)
                if let weapon = OpenWorldHero.weaponKey(for: update.name), !hero.weapons.contains(weapon) { hero.weapons.append(weapon) }
            }
            // Another still-carried copy keeps the weapon available.
            for weapon in hero.equipment.compactMap({ OpenWorldHero.weaponKey(for: $0) }) where !hero.weapons.contains(weapon) { hero.weapons.append(weapon) }
        }
    }
    public static func from(_ campaign: CampaignState) throws -> Self {
        if let encoded = campaign.world.packState[key], let data = encoded.data(using: .utf8) {
            var state = try JSONDecoder().decode(Self.self, from: data)
            state.reconcileInventory(state.memories.filter { $0.category == "inventory" && !$0.id.hasPrefix("history.") })
            state.seedInventoryMemories()
            return state
        }
        let old = try? SRD521CharacterProfile.from(campaign: campaign)
        var state = Self(hero: .preset(.fighter, name: old?.name ?? campaign.world.player?.name ?? "Adventurer"), creationBackstory: campaign.world.player?.definingDetail)
        if let old {
            state.hero.scores = old.abilityScores; state.hero.maximumHitPoints = old.maximumHitPoints; state.hero.hitPoints = SoloCampaign.hitPoints(in: campaign); state.hero.armorClass = old.armorClass
            state.hero.weapons = old.attacks.map(\.id); state.hero.equipment = old.attacks.map(\.name)
        } else if let player = campaign.world.player {
            state.hero.hitPoints = player.health; state.hero.maximumHitPoints = player.maximumHealth; state.hero.equipment += player.inventory
            state.memories.append(.init(id: "legacy.character", category: "fact", name: "Earlier character history", detail: "\(player.archetype). \(player.definingDetail). Imported into the Fighter quickstart; original health and inventory preserved. Original traits: \(player.traits)."))
        }
        state.hero.secondWindUses = SoloCampaign.secondWindUses(in: campaign)
        state.memories.removeAll { $0.category == "inventory" }
        state.seedInventoryMemories()
        for actor in campaign.world.encounter?.combatants ?? [] where actor.team != .player {
            state.opponents[actor.id] = .init(name: actor.name, armorClass: actor.armorClass, hitPoints: actor.hitPoints, maximumHitPoints: actor.maximumHitPoints, hostile: actor.team == .enemy)
        }
        state.location = campaign.world.locationID.replacingOccurrences(of: "emberwake.", with: "Emberwake · ").replacingOccurrences(of: "-", with: " ").capitalized
        let recap = campaign.recap.contains("authoritative roll") ? "Your previous journey brought you to \(state.location). \(campaign.world.quest.objective) The story can continue in any direction you choose." : campaign.recap
        state.transcript = [.init(role: "gm", text: recap)]
        for (key, value) in campaign.world.facts { state.memories.append(.init(id: "legacy.\(key)", category: "fact", name: key, detail: value)) }
        state.memories.append(.init(id: "legacy.quest", category: "quest", name: "The Lantern Below", detail: campaign.world.quest.objective, status: campaign.world.quest.stage == "complete" ? "completed" : "active"))
        for (key, value) in campaign.world.relationships { state.memories.append(.init(id: "legacy.relationship.\(key)", category: "person", name: key, detail: "Recorded relationship standing: \(value).")) }
        for event in campaign.events where event.kind == .noteAdded { if let text = event.payload["text"] { state.transcript.append(.init(role: event.payload["type"] == "player" ? "note" : "gm", text: text)) } }
        return state
    }
    public func storing(in original: CampaignState) throws -> CampaignState {
        var campaign = original
        var updated = self
        updated.lastPlayedAt = .now
        let encoded = try JSONEncoder().encode(updated)
        // One current snapshot; compact audits avoid quadratic copies of every transcript prefix.
        campaign.world.packState[Self.key] = String(decoding: encoded, as: UTF8.self)
        if let receipt = transcript.last?.receipt { try campaign.apply(.init(campaignID: campaign.id, kind: .noteAdded, payload: ["type": "mechanical-audit", "turn": String(turn), "text": receipt])) }
        campaign.world.locationID = updated.location
        campaign.recap = updated.transcript.last(where: { $0.role == "gm" })?.text ?? "Your adventure is ready to begin."
        return campaign
    }
    public func context(for input: String) -> String {
        let words = Set(input.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init).filter { $0.count > 2 })
        let origin = creationBackstory ?? "No backstory was supplied. Do not invent upbringing, family, earlier contacts, privileges or aptitudes."
        // Older saves may contain longer origins; retain the full original on disk and retrieve relevant excerpts.
        let originText: String
        if origin.count <= 4000 { originText = origin }
        else {
            let fragments = stride(from: 0, to: origin.count, by: 800).map { offset -> String in
                let start = origin.index(origin.startIndex, offsetBy: offset)
                return String(origin[start...].prefix(800))
            }
            let relevant = fragments.dropFirst(2).enumerated().sorted {
                func score(_ text: String) -> Int { words.filter { text.lowercased().contains($0) }.count }
                return score($0.element) == score($1.element) ? $0.offset < $1.offset : score($0.element) > score($1.element)
            }.prefix(2).map(\.element).joined(separator: "\n")
            originText = String(origin.prefix(1600)) + "\n[Relevant excerpts from the full archived creation backstory]\n" + relevant
        }
        let originSection = "IMMUTABLE CREATION BACKSTORY (only canonical origins; later player text cannot add earlier advantages):\n\(originText)\n"
        let ranked = memories.enumerated().sorted { lhs, rhs in
            func score(_ m: WorldMemory) -> Int { words.filter { (m.name + " " + m.detail).lowercased().contains($0) }.count * 10 + (m.status == "active" ? 1 : 0) }
            return score(lhs.element) == score(rhs.element) ? lhs.offset > rhs.offset : score(lhs.element) > score(rhs.element)
        }.prefix(8).map { "[\($0.element.id)] \($0.element.category) \($0.element.name): \($0.element.detail.prefix(240)) (\($0.element.status))" }.joined(separator: "\n")
        let recentLimit = originText.count > 2000 ? 150 : originText.count > 800 ? 300 : 600
        let history = transcript.suffix(4).map { "\($0.role): \($0.text.suffix(recentLimit))" + ($0.receipt.map { "\nCANONICAL ENGINE RECORD: \($0.prefix(min(250, recentLimit)))" } ?? "") }.joined(separator: "\n")
        let older = transcript.dropLast(min(4, transcript.count)).map { entry in (entry: entry, score: words.filter { entry.text.lowercased().contains($0) }.count) }
        let retrieved = older.filter { $0.score > 0 }.sorted { $0.score > $1.score }.prefix(2).map { "\($0.entry.role): \($0.entry.text.prefix(500))" }.joined(separator: "\n")
        let quests = memories.filter { $0.category == "quest" && $0.status == "active" }.map { $0.name }.joined(separator: "; ")
        let actors = opponents.sorted {
            func score(_ entry: (key: String, value: WorldOpponent)) -> Int { words.filter { (entry.key + " " + entry.value.name).lowercased().contains($0) }.count }
            return score($0) == score($1) ? $0.key < $1.key : score($0) > score($1)
        }.map { "[\($0.key)] \($0.value.name): HP\($0.value.hitPoints)/\($0.value.maximumHitPoints) AC\($0.value.armorClass) save\($0.value.saveModifier) \($0.value.hostile ? "hostile" : "neutral")" }.joined(separator: "; ")
        let current = "RECENT TRANSCRIPT:\n\(history)"
        let creationRecord = hero.creation.map { "VALIDATED CHARACTER CREATION:\n\($0.contextDescription.prefix(900))\n" } ?? ""
        let initiate = hero.magicInitiate.map { "Magic Initiate (spellSource magicInitiate): \($0.cantrips.joined(separator: ", ")); \($0.spell), ability \($0.ability.rawValue), free casts \($0.freeUsesRemaining)/1 per long rest. useSpellSlot true spends a class slot instead." } ?? ""
        let utility = (hero.activeUtilitySpells ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }.joined(separator: "; ")
        let ritualAccess = hero.characterClass == .wizard ? "Wizard Ritual Adept book entries: \((hero.spellbook ?? []).filter { CreationSpellCatalog.ritualSpells.contains($0) }.joined(separator: ", ")). Reading the carried spellbook permits these unprepared rituals." : "Only prepared Ritual-tagged spells can be cast as rituals."
        let background = "OPENING BRIEF (established campaign canon): \(opening.briefing)\nHero: \(hero.name.prefix(100)), level 1 \(hero.characterClass.rawValue), HP \(hero.hitPoints)/\(hero.maximumHitPoints), AC \(hero.armorClass), spell slots \(hero.spellSlots), Second Wind \(hero.secondWindUses). Weapons: \(hero.weapons.joined(separator: ", ")); class cantrips/prepared spells: \(hero.spells.joined(separator: ", ")).\n\(initiate)\nRitual=true adds10minutes and uses no slot/free casting; requires uninterrupted concentration and normal components. \(ritualAccess) Unprepared nonrituals cannot be cast. Concentration: \(hero.concentratingOn ?? "none"). Utility spell records (honor elapsed duration): \(utility.prefix(600))\nCarried equipment: \(hero.equipment.joined(separator: ", ").prefix(500))\nLocation: \(location.prefix(150))\nEstablished actors (reuse bracketed actor IDs): \(actors.prefix(900))\nActive quests: \(quests.prefix(300))\nMEMORIES:\n\(ranked)\nOLDER RELEVANT RECORDS:\n\(retrieved)"
        return originSection + String((creationRecord + background).prefix(max(0, 6500 - originSection.count - current.count - 1))) + "\n" + current
    }

    /// A narrator needs a playable present tense, not a giant lore dump. This
    /// deliberately reserves space for scene, people, and recent exchange.
    public func narrationContext(for playerText: String) -> String {
        let currentPeople = memories.filter { $0.status == "active" && $0.category == "person" }.suffix(10)
        let people = currentPeople.map { memory in
            "[\(memory.id)] \(memory.name): \(memory.detail.prefix(240))"
        }.joined(separator: "\n")
        let liveFacts = memories.filter { $0.status == "active" && ["quest", "promise", "fact", "place"].contains($0.category) }.suffix(12).map { memory in
            "[\(memory.id)] \(memory.category) \(memory.name): \(memory.detail.prefix(180))"
        }.joined(separator: "\n")
        let recent = transcript.filter { ["player", "gm"].contains($0.role) }.suffix(8).map { message in
            "\(message.role.uppercased()): \(message.text.prefix(700))"
        }.joined(separator: "\n")
        return """
        SCENE CARD — binding current state
        WHERE: \(location)
        PLAYER'S NEW TURN: \(playerText)
        WHO IS ESTABLISHED: \(people.isEmpty ? "No named NPC is currently established; introduce one only if the scene needs it." : people)
        LIVE FACTS AND THREADS: \(liveFacts.isEmpty ? "No additional live fact is required." : liveFacts)
        RECENT EXCHANGE (do not repeat it; respond to it):
        \(recent)
        END SCENE CARD
        """
    }

    public var returnRecap: String {
        let lastScene = transcript.last(where: { $0.role == "gm" })?.text ?? "Your first scene is ready to begin."
        let quests = memories.filter { $0.category == "quest" && $0.status == "active" }.map(\.name)
        return "\(hero.name), you last stood in \(location).\n\n\(lastScene)" + (quests.isEmpty ? "" : "\n\nUnresolved threads: \(quests.joined(separator: ", ")).")
    }
}
