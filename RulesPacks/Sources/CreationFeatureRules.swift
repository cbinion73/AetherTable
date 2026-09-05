import Foundation

/// Explicit resources whose expenditure must be saved with the resolved turn.
public struct CreationFeatureResources: Codable, Hashable, Sendable {
    public var heroicInspiration: Bool
    public init(heroicInspiration: Bool = false) { self.heroicInspiration = heroicInspiration }
    public mutating func finishLongRest(isHuman: Bool) {
        if isHuman { heroicInspiration = true }
    }
}

public enum CreationFeatureError: Error, Equatable {
    case invalidDice, replacementRequired, unavailableFeature
}

public struct CreationD20Result: Hashable, Sendable {
    public var originalDice: [Int]
    public var dice: [Int]
    public var selectedDie: Int
    public var luckUsed: Bool
}

public struct CreationWeaponDamage: Hashable, Sendable {
    public var dice: [Int]
    public var alternateDice: [Int]?
    public var total: Int
    public var savageAttackerUsed: Bool
}

public struct CreationInspirationResult: Hashable, Sendable {
    public var dice: [Int]
    public var resources: CreationFeatureResources
}

/// SRD 5.2.1 pp.8,84,86–88. Randomness comes from the caller's audited dice stream.
/// These helpers do not infer equipment, conditions, turn boundaries, or player consent.
public enum CreationFeatureRules {
    /// Halfling Luck rerolls one natural 1 once; even with advantage/disadvantage,
    /// a reroll feature can replace only one die (p.8). The replacement must be used.
    public static func d20(dice: [Int], mode: SRD521RollMode, halflingLuck: Bool, replacementDie: Int? = nil) throws -> CreationD20Result {
        guard dice.count == (mode == .normal ? 1 : 2), dice.allSatisfy({ (1...20).contains($0) }) else { throw CreationFeatureError.invalidDice }
        var adjusted = dice
        var used = false
        if halflingLuck, let index = dice.firstIndex(of: 1) {
            guard let replacementDie else { throw CreationFeatureError.replacementRequired }
            guard (1...20).contains(replacementDie) else { throw CreationFeatureError.invalidDice }
            adjusted[index] = replacementDie
            used = true
        }
        let selected = mode == .advantage ? adjusted.max()! : mode == .disadvantage ? adjusted.min()! : adjusted[0]
        return .init(originalDice: dice, dice: adjusted, selectedDie: selected, luckUsed: used)
    }

    public static func rangedAttackBonus(archery: Bool, isRanged: Bool) -> Int { archery && isRanged ? 2 : 0 }
    public static func armorClassBonus(defense: Bool, wearingArmor: Bool) -> Int { defense && wearingArmor ? 1 : 0 }
    public static func dwarfHitPointBonus(isDwarf: Bool, level: Int) -> Int { isDwarf ? max(0, level) : 0 }

    /// Caller establishes that the attack is melee, held in two hands, and the
    /// weapon has Two-Handed or Versatile before enabling Great Weapon Fighting.
    /// Pass weapon dice only, including extra weapon dice from a critical hit.
    /// A second set spends Savage Attacker's once-per-turn use; nil declines it.
    public static func weaponDamage(first: [Int], second: [Int]? = nil, sides: Int, modifier: Int, greatWeaponFighting: Bool, savageAttackerAvailable: Bool) throws -> CreationWeaponDamage {
        guard sides >= 3, !first.isEmpty, first.allSatisfy({ (1...sides).contains($0) }) else { throw CreationFeatureError.invalidDice }
        if let second {
            guard savageAttackerAvailable else { throw CreationFeatureError.unavailableFeature }
            guard second.count == first.count, second.allSatisfy({ (1...sides).contains($0) }) else { throw CreationFeatureError.invalidDice }
        }
        func adjusted(_ dice: [Int]) -> [Int] { greatWeaponFighting ? dice.map { max(3, $0) } : dice }
        let primary = adjusted(first)
        let alternate = second.map(adjusted)
        let chosen = (alternate?.reduce(0, +) ?? -1) > primary.reduce(0, +) ? alternate! : primary
        return .init(dice: chosen, alternateDice: alternate, total: max(0, chosen.reduce(modifier, +)), savageAttackerUsed: second != nil)
    }

    /// Heroic Inspiration replaces one selected die of any roll, not the entire
    /// roll. The caller must offer this immediately after rolling (SRD p.8).
    public static func spendHeroicInspiration(dice: [Int], sides: Int, index: Int, replacementDie: Int, resources: CreationFeatureResources) throws -> CreationInspirationResult {
        guard resources.heroicInspiration else { throw CreationFeatureError.unavailableFeature }
        guard sides > 0, dice.indices.contains(index), dice.allSatisfy({ (1...sides).contains($0) }), (1...sides).contains(replacementDie) else { throw CreationFeatureError.invalidDice }
        var adjusted = dice
        adjusted[index] = replacementDie
        var remaining = resources
        remaining.heroicInspiration = false
        return .init(dice: adjusted, resources: remaining)
    }

    public static func dwarfPoisonSavingThrowAdvantage(isDwarf: Bool, avoidingOrEndingPoisoned: Bool) -> Bool {
        isDwarf && avoidingOrEndingPoisoned
    }
    public static func damageAfterDwarvenResistance(_ damage: Int, isDwarf: Bool, damageType: String) -> Int {
        let amount = max(0, damage)
        return isDwarf && damageType.lowercased() == "poison" ? amount / 2 : amount
    }
}
