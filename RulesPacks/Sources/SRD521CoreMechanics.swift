import DiceEngine
import Foundation

/// Deterministic adjudication for the core d20 test sequence described in SRD
/// 5.2.1. This adapter covers only the mechanics named here; it is not a claim
/// to implement every rule, option, spell, creature, or item in the document.
public enum SRD521Ability: String, CaseIterable, Codable, Sendable {
    case strength, dexterity, constitution, intelligence, wisdom, charisma
}

public enum SRD521TestKind: String, Codable, Sendable {
    case abilityCheck
    case savingThrow
    case attackRoll
}

public enum SRD521RollMode: String, Codable, Sendable {
    case normal, advantage, disadvantage

    public static func effective(hasAdvantage: Bool, hasDisadvantage: Bool) -> Self {
        switch (hasAdvantage, hasDisadvantage) {
        case (true, false): .advantage
        case (false, true): .disadvantage
        default: .normal
        }
    }
}

public struct SRD521TestRequest: Sendable {
    public let kind: SRD521TestKind
    public let ability: SRD521Ability
    public let abilityScore: Int
    public let proficiencyBonus: Int
    public let isProficient: Bool
    public let target: Int
    public let rollMode: SRD521RollMode
    public let circumstanceModifier: Int

    public init(
        kind: SRD521TestKind,
        ability: SRD521Ability,
        abilityScore: Int,
        proficiencyBonus: Int = 0,
        isProficient: Bool = false,
        target: Int,
        rollMode: SRD521RollMode = .normal,
        circumstanceModifier: Int = 0
    ) {
        self.kind = kind
        self.ability = ability
        self.abilityScore = abilityScore
        self.proficiencyBonus = proficiencyBonus
        self.isProficient = isProficient
        self.target = target
        self.rollMode = rollMode
        self.circumstanceModifier = circumstanceModifier
    }
}

public enum SRD521TestOutcome: String, Sendable {
    case success, failure, criticalHit, automaticMiss
}

public struct SRD521TestResult: Sendable {
    public let request: SRD521TestRequest
    public let dice: [Int]
    public let selectedDie: Int
    public let abilityModifier: Int
    public let proficiencyApplied: Int
    public let total: Int
    public let outcome: SRD521TestOutcome
}

public enum SRD521CoreRulesError: Error, Equatable {
    case invalidAbilityScore(Int)
    case invalidProficiencyBonus(Int)
    case invalidTarget(Int)
    case wrongDiceCount(expected: Int, actual: Int)
    case invalidDie(Int)
}

public enum SRD521CoreMechanics {
    public static func proficiencyBonus(forCharacterLevel level: Int) -> Int? {
        switch level {
        case 1...4: 2
        case 5...8: 3
        case 9...12: 4
        case 13...16: 5
        case 17...20: 6
        default: nil
        }
    }

    public static func abilityModifier(for score: Int) throws -> Int {
        guard (1...30).contains(score) else { throw SRD521CoreRulesError.invalidAbilityScore(score) }
        return Int(floor(Double(score - 10) / 2.0))
    }

    public static func roll(request: SRD521TestRequest, seed: UInt64) throws -> SRD521TestResult {
        let diceCount = request.rollMode == .normal ? 1 : 2
        let dice = try DiceEngine.roll(.init(count: diceCount, sides: 20), seed: seed).values
        return try resolve(request: request, dice: dice)
    }

    /// Exposed for repeatable conformance tests and authoritative multiplayer
    /// replay. Callers should retain both input dice and result in the event log.
    public static func resolve(request: SRD521TestRequest, dice: [Int]) throws -> SRD521TestResult {
        guard (0...20).contains(request.proficiencyBonus) else { throw SRD521CoreRulesError.invalidProficiencyBonus(request.proficiencyBonus) }
        guard request.target > 0 else { throw SRD521CoreRulesError.invalidTarget(request.target) }
        let expectedDice = request.rollMode == .normal ? 1 : 2
        guard dice.count == expectedDice else { throw SRD521CoreRulesError.wrongDiceCount(expected: expectedDice, actual: dice.count) }
        guard dice.allSatisfy({ (1...20).contains($0) }) else { throw SRD521CoreRulesError.invalidDie(dice.first(where: { !(1...20).contains($0) }) ?? 0) }

        let selectedDie: Int
        switch request.rollMode {
        case .normal: selectedDie = dice[0]
        case .advantage: selectedDie = dice.max()!
        case .disadvantage: selectedDie = dice.min()!
        }

        let ability = try abilityModifier(for: request.abilityScore)
        let proficiency = request.isProficient ? request.proficiencyBonus : 0
        let total = selectedDie + ability + proficiency + request.circumstanceModifier

        let outcome: SRD521TestOutcome
        if request.kind == .attackRoll, selectedDie == 20 {
            outcome = .criticalHit
        } else if request.kind == .attackRoll, selectedDie == 1 {
            outcome = .automaticMiss
        } else {
            outcome = total >= request.target ? .success : .failure
        }

        return .init(
            request: request,
            dice: dice,
            selectedDie: selectedDie,
            abilityModifier: ability,
            proficiencyApplied: proficiency,
            total: total,
            outcome: outcome
        )
    }
}
