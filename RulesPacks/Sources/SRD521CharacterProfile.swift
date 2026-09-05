import AetherTableCore
import Foundation

/// The smallest complete, persistent character record needed to enter an SRD
/// 5.2.1 encounter. Class features and spellcasting will extend this record in
/// later records; the foundation remains stable for saved campaigns and sync.
public struct SRD521CharacterProfile: Codable, Hashable, Sendable {
    public static let stateKey = "srd-5.2.1.character"

    public struct WeaponAttack: Codable, Hashable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let ability: SRD521Ability
        public let damage: DiceSpecification
        public let isProficient: Bool

        public init(id: String, name: String, ability: SRD521Ability, damage: DiceSpecification, isProficient: Bool = true) {
            self.id = id; self.name = name; self.ability = ability; self.damage = damage; self.isProficient = isProficient
        }
    }

    public let name: String
    public let characterClass: String
    public let background: String
    public let level: Int
    public let abilityScores: [SRD521Ability: Int]
    public let maximumHitPoints: Int
    public let armorClass: Int
    public let proficientSavingThrows: Set<SRD521Ability>
    public let attacks: [WeaponAttack]

    public init(name: String, characterClass: String, background: String, level: Int = 1, abilityScores: [SRD521Ability: Int], maximumHitPoints: Int, armorClass: Int, proficientSavingThrows: Set<SRD521Ability>, attacks: [WeaponAttack]) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !characterClass.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !background.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              level == 1,
              maximumHitPoints > 0,
              armorClass > 0,
              !attacks.isEmpty,
              SRD521Ability.allCases.allSatisfy({ (1...20).contains(abilityScores[$0] ?? 0) })
        else { throw SRD521CharacterProfileError.invalidLevelOneProfile }
        self.name = name; self.characterClass = characterClass; self.background = background; self.level = level
        self.abilityScores = abilityScores; self.maximumHitPoints = maximumHitPoints; self.armorClass = armorClass
        self.proficientSavingThrows = proficientSavingThrows; self.attacks = attacks
    }

    public var proficiencyBonus: Int { SRD521CoreMechanics.proficiencyBonus(forCharacterLevel: level) ?? 2 }

    public func attackRequest(attackID: String, targetID: String, rollMode: SRD521RollMode = .normal) throws -> SRD521AttackRequest {
        guard let attack = attacks.first(where: { $0.id == attackID }), let score = abilityScores[attack.ability] else { throw SRD521CharacterProfileError.missingAttack }
        return .init(attackerID: "player", targetID: targetID, ability: attack.ability, abilityScore: score, proficiencyBonus: proficiencyBonus, isProficient: attack.isProficient, damage: attack.damage, rollMode: rollMode)
    }

    public func stateEvent(campaignID: CampaignID) throws -> CampaignEvent {
        let data = try JSONEncoder().encode(self)
        guard let value = String(data: data, encoding: .utf8) else { throw SRD521CharacterProfileError.encodingFailed }
        return CampaignEvent(campaignID: campaignID, kind: .packStateSet, payload: ["key": Self.stateKey, "value": value])
    }

    public static func from(campaign: CampaignState) throws -> Self {
        guard let value = campaign.world.packState[stateKey], let data = value.data(using: .utf8) else { throw SRD521CharacterProfileError.notConfigured }
        return try JSONDecoder().decode(Self.self, from: data)
    }
}

public enum SRD521CharacterProfileError: Error, Equatable {
    case invalidLevelOneProfile, missingAttack, encodingFailed, notConfigured
}

/// A source-backed starting profile lets the app expose a complete, real
/// character before the full class/options builder is available.
public enum SRD521QuickstartCharacter {
    public static func guardian(name: String = "Arden") throws -> SRD521CharacterProfile {
        try .init(
            name: name,
            characterClass: "Fighter",
            background: "Soldier",
            abilityScores: [.strength: 16, .dexterity: 12, .constitution: 14, .intelligence: 10, .wisdom: 10, .charisma: 8],
            maximumHitPoints: 12,
            armorClass: 16,
            proficientSavingThrows: [.strength, .constitution],
            attacks: [.init(id: "longsword", name: "Longsword", ability: .strength, damage: .init(count: 1, sides: 8, modifier: 3))]
        )
    }
}
