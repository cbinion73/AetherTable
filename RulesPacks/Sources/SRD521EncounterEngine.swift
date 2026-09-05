import AetherTableCore
import DiceEngine
import Foundation

/// A deterministic SRD 5.2.1 combat action. A caller supplies the ability and
/// training facts; rules content can later construct this request from a class,
/// weapon, spell, or monster record.
public struct SRD521AttackRequest: Sendable {
    public let attackerID: String
    public let targetID: String
    public let ability: SRD521Ability
    public let abilityScore: Int
    public let proficiencyBonus: Int
    public let isProficient: Bool
    public let damage: DiceSpecification
    public let rollMode: SRD521RollMode

    public init(attackerID: String, targetID: String, ability: SRD521Ability, abilityScore: Int, proficiencyBonus: Int, isProficient: Bool, damage: DiceSpecification, rollMode: SRD521RollMode = .normal) {
        self.attackerID = attackerID; self.targetID = targetID; self.ability = ability; self.abilityScore = abilityScore
        self.proficiencyBonus = proficiencyBonus; self.isProficient = isProficient; self.damage = damage; self.rollMode = rollMode
    }
}

public struct SRD521AttackResolution: Sendable {
    public let attack: SRD521TestResult
    public let damage: Int
    public let damageDice: [Int]
    public let events: [CampaignEvent]
}

public enum SRD521EncounterError: Error, Equatable {
    case missingEncounter, inactiveEncounter, notActiveCombatant, missingTarget, defeatedCombatant
    case invalidDamageExpression
}

public enum SRD521EncounterEngine {
    public static func startEvents(campaignID: CampaignID, encounterID: String, title: String, combatants: [EncounterCombatant]) -> [CampaignEvent] {
        let start = CampaignEvent(campaignID: campaignID, kind: .encounterStarted, payload: ["encounterID": encounterID, "title": title])
        let joins = combatants.map {
            CampaignEvent(campaignID: campaignID, kind: .combatantJoined, payload: [
                "combatantID": $0.id, "name": $0.name, "team": $0.team.rawValue,
                "initiative": String($0.initiative), "maximumHitPoints": String($0.maximumHitPoints), "armorClass": String($0.armorClass)
            ])
        }
        let first = combatants.sorted { $0.initiative == $1.initiative ? $0.id < $1.id : $0.initiative > $1.initiative }.first
        let turn = first.map { CampaignEvent(campaignID: campaignID, kind: .turnStarted, payload: ["combatantID": $0.id, "round": "1"]) }
        return [start] + joins + (turn.map { [$0] } ?? [])
    }

    public static func resolveAttack(campaignID: CampaignID, in encounter: EncounterState, request: SRD521AttackRequest, attackDice: [Int], damageDice: [Int]) throws -> SRD521AttackResolution {
        guard encounter.status == .active else { throw SRD521EncounterError.inactiveEncounter }
        guard encounter.activeCombatantID == request.attackerID else { throw SRD521EncounterError.notActiveCombatant }
        guard let attacker = encounter.combatants.first(where: { $0.id == request.attackerID }), attacker.hitPoints > 0 else { throw SRD521EncounterError.defeatedCombatant }
        guard let target = encounter.combatants.first(where: { $0.id == request.targetID }), target.hitPoints > 0 else { throw SRD521EncounterError.missingTarget }

        let attack = try SRD521CoreMechanics.resolve(
            request: .init(kind: .attackRoll, ability: request.ability, abilityScore: request.abilityScore, proficiencyBonus: request.proficiencyBonus, isProficient: request.isProficient, target: target.armorClass, rollMode: request.rollMode),
            dice: attackDice
        )

        let action = CampaignEvent(campaignID: campaignID, kind: .actionResolved, payload: [
            "verb": "attack", "detail": "(attacker.name) attacks (target.name)", "ruleID": "srd-5.2.1.playing-the-game.attack-rolls",
            "attackerID": attacker.id, "targetID": target.id, "target": String(target.armorClass), "total": String(attack.total),
            "dice": attack.dice.map(String.init).joined(separator: ","), "outcome": attack.outcome.rawValue
        ])

        guard attack.outcome == .success || attack.outcome == .criticalHit else {
            return .init(attack: attack, damage: 0, damageDice: [], events: [action])
        }
        let multiplier = attack.outcome == .criticalHit ? 2 : 1
        let expectedDice = request.damage.count * multiplier
        guard damageDice.count == expectedDice, damageDice.allSatisfy({ (1...request.damage.sides).contains($0) }) else { throw SRD521EncounterError.invalidDamageExpression }
        let damage = damageDice.reduce(request.damage.modifier, +)
        let damageEvent = CampaignEvent(campaignID: campaignID, kind: .combatantDamaged, payload: [
            "combatantID": target.id, "damage": String(damage), "ruleID": "srd-5.2.1.combat.damage", "damageDice": damageDice.map(String.init).joined(separator: ",")
        ])
        return .init(attack: attack, damage: damage, damageDice: damageDice, events: [action, damageEvent])
    }

    public static func nextTurnEvent(campaignID: CampaignID, encounter: EncounterState) throws -> CampaignEvent {
        guard encounter.status == .active, let activeID = encounter.activeCombatantID, let activeIndex = encounter.combatants.firstIndex(where: { $0.id == activeID }) else { throw SRD521EncounterError.missingEncounter }
        let living = encounter.combatants.filter { $0.hitPoints > 0 }
        guard !living.isEmpty else { throw SRD521EncounterError.missingEncounter }
        let ordered = encounter.combatants
        var nextIndex = (activeIndex + 1) % ordered.count
        while ordered[nextIndex].hitPoints == 0 { nextIndex = (nextIndex + 1) % ordered.count }
        let next = ordered[nextIndex]
        let round = nextIndex <= activeIndex ? encounter.round + 1 : encounter.round
        return CampaignEvent(campaignID: campaignID, kind: .turnStarted, payload: ["combatantID": next.id, "round": String(round)])
    }
}
