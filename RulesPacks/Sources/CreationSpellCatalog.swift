import Foundation

public struct MagicInitiateGrant: Codable, Hashable, Sendable {
    public var cantrips: [String]
    public var spell: String
    public var ability: SRD521Ability
    public var freeUsesRemaining: Int
    public init(cantrips: [String], spell: String, ability: SRD521Ability, freeUsesRemaining: Int = 1) {
        self.cantrips = cantrips; self.spell = spell; self.ability = ability; self.freeUsesRemaining = freeUsesRemaining
    }
}

/// Supported subset of SRD 5.2.1 class lists (Cleric p38, Wizard p79) and spell descriptions.
/// Utility effects are bounded narrative adjudication; durations are recorded, not a tactical clock.
public enum CreationSpellCatalog {
    /// SRD 5.2.1 Ritual tags; ordinary casting time is preserved before the ten-minute addition.
    public static let ritualSpells: Set<String> = ["alarm", "comprehend languages", "detect magic", "detect poison and disease", "identify", "illusory script", "purify food and drink", "unseen servant"]
    public static func ritualCastingTime(for spell: String) -> String? {
        guard ritualSpells.contains(spell) else { return nil }
        return ["alarm", "identify", "illusory script"].contains(spell) ? "11 minutes (normal 1 minute + 10 minutes)" : "10 minutes plus the normal Magic action"
    }
    public struct Definition: Sendable {
        public let level: Int
        public let limits: String
        public let requiredItem: String?
        public let consumesItem: Bool
        public let concentration: Bool
        public init(level: Int, limits: String, requiredItem: String? = nil, consumesItem: Bool = false, concentration: Bool = false) {
            self.level = level; self.limits = limits; self.requiredItem = requiredItem; self.consumesItem = consumesItem; self.concentration = concentration
        }
    }
    public static func cantrips(for characterClass: AdventurerClass) -> [String] {
        switch characterClass {
        case .bard: ["light", "mending", "prestidigitation"]
        case .wizard: ["fire bolt", "light", "mage hand", "mending", "prestidigitation"]
        case .cleric: ["light", "mending", "sacred flame", "thaumaturgy"]
        case .druid: ["light", "mending"]
        case .sorcerer: ["fire bolt", "light", "mage hand", "mending", "prestidigitation"]
        case .warlock: ["fire bolt", "mage hand", "prestidigitation"]
        default: []
        }
    }
    public static func levelOneSpells(for characterClass: AdventurerClass) -> [String] {
        switch characterClass {
        case .bard: ["cure wounds", "detect magic", "disguise self", "healing word"]
        case .wizard: ["alarm", "comprehend languages", "detect magic", "disguise self", "identify", "illusory script", "magic missile", "unseen servant"]
        case .cleric: ["create or destroy water", "cure wounds", "detect magic", "detect poison and disease", "guiding bolt", "healing word", "purify food and drink"]
        case .druid: ["cure wounds", "detect magic", "detect poison and disease", "purify food and drink"]
        case .paladin: ["cure wounds", "detect magic"]
        case .ranger: ["cure wounds", "detect magic"]
        case .sorcerer: ["detect magic", "magic missile"]
        case .warlock: ["detect magic", "magic missile"]
        default: []
        }
    }
    public static let utilities: [String: Definition] = [
        "light": .init(level: 0, limits: "Action; touch one unattended or willingly offered object up to10feet across. For1hour it sheds bright light20feet and dim light20feet farther. Opaque covering blocks it. One active Light object; hostile-held-object saves are outside this beta."),
        "mage hand": .init(level: 0, limits: "Action; spectral hand within30feet for1minute, carrying at most10pounds. Can manipulate objects/open unlocked containers/stow or retrieve items/pour a vial. Cannot attack, activate magic items, or move beyond30feet."),
        "mending": .init(level: 0, limits: "1minute casting; touch an object and repair one break or tear no larger than1foot. Can physically repair a magic item but cannot restore lost magic."),
        "prestidigitation": .init(level: 0, limits: "Action within10feet: harmless sensory effect; light/snuff a small flame; clean/soil an object up to1cubic foot; flavor/chill/warm up to1cubic foot of nonliving material for1hour; small mark for1hour; tiny trinket/illusion until next turn. At most3 noninstantaneous effects. Cannot harm, create valuables, or replicate other spells."),
        "thaumaturgy": .init(level: 0, limits: "Action within30feet: voice up to3times louder, alter flames, harmless tremors, instantaneous sound, open/slam an unlocked door/window, or alter eye appearance. Noninstantaneous effects last1minute; at most3. No damage or unlocking."),
        "detect magic": .init(level: 1, limits: "Action; concentration up to10minutes. Sense magic within30feet; Magic action reveals a visible bearer’s aura and spell school. Blocked by1foot of stone/dirt/wood,1inch metal, or thin lead. Does not identify all item properties or reveal hidden creatures.", concentration: true),
        "identify": .init(level: 1, limits: "1minute casting while touching an object: learn magical properties, use, attunement and charges, or spells affecting it. Touching a creature reveals spells currently affecting it. Requires an unconsumed pearl worth100GP and an owl feather.", requiredItem: "Pearl (100 GP)"),
        "comprehend languages": .init(level: 1, limits: "Action; self;1hour. Understand literal spoken/signed language. Read touched writing at1minute/page. Does not decipher secret messages, grant speaking fluency or reveal hidden meaning."),
        "disguise self": .init(level: 1, limits: "Action; self;1hour. Visual illusion changes clothing/equipment/appearance, at most1foot height difference; same arrangement of limbs. Does not withstand physical inspection or change statistics. An examining creature can use Study/Investigation versus spell DC."),
        "unseen servant": .init(level: 1, limits: "Action; create a mindless invisible Medium force within60feet for1hour, AC10 HP1 Strength2. Cannot attack. Bonus-action commands move it up to15feet and perform simple ordinary tasks. Ends at0HP or when a task moves it over60feet away."),
        "alarm": .init(level: 1, limits: "1minute casting within30feet; ward a door/window or area up to20foot cube for8hours. Tiny or larger undesignated creatures entering trigger a mental alert within1mile or audible handbell within60feet for10seconds. Does not damage, identify or restrain intruders."),
        "illusory script": .init(level: 1, limits: "1minute casting; touch writing; lasts10days. Designated readers see intended text; others see unreadable or alternative text in a language you know. Truesight reveals original. Consumes ink worth10GP. No forged authority or automatic deception success.", requiredItem: "Fine ink (10 GP)", consumesItem: true),
        "purify food and drink": .init(level: 1, limits: "Action within10feet; instantaneous. Remove poison and rot from nonmagical food/drink in a5foot-radius sphere. Does not create food or purify a creature."),
        "create or destroy water": .init(level: 1, limits: "Action within30feet; instantaneous. Create up to10gallons of clean water in an open container or rain in a30foot cube extinguishing exposed flames; alternatively destroy up to10gallons in an open container or fog in a30foot cube. Cannot create water inside a creature or deal automatic damage."),
        "detect poison and disease": .init(level: 1, limits: "Action; self; concentration up to10minutes. Sense location and kind of poison, venomous creatures and magical contagions within30feet. Blocked by1foot stone/dirt/wood,1inch metal, or thin lead. Does not cure them.", concentration: true)
    ]
    public static func level(of spell: String) -> Int? {
        if let definition = utilities[spell] { return definition.level }
        if ["fire bolt", "sacred flame"].contains(spell) { return 0 }
        if ["magic missile", "cure wounds", "healing word", "guiding bolt"].contains(spell) { return 1 }
        return nil
    }
}
