import AetherTableCore
import DiceEngine
import Foundation

public enum CheckDifficulty: String, Sendable { case steady, risky, dire, legendary
    public var target: Int { switch self { case .steady: 10; case .risky: 13; case .dire: 16; case .legendary: 19 } }
}

public enum ResolutionBand: String, Sendable { case fullSuccess, successWithCost, miss, criticalSuccess, criticalComplication }

public struct PlayerIntent: Hashable, Sendable {
    public let verb: String
    public let detail: String
    public let trait: CharacterTrait
    public let difficulty: CheckDifficulty
    public init(verb: String, detail: String, trait: CharacterTrait = .wits, difficulty: CheckDifficulty = .risky) {
        self.verb = verb; self.detail = detail; self.trait = trait; self.difficulty = difficulty
    }
}
public enum RulesOutcome: Sendable { case accepted(CampaignEvent); case rejected(reason: String) }

public struct RulesEngine: Sendable {
    public init() {}
    public func resolve(intent: PlayerIntent, in campaign: CampaignState, using pack: any RulesPack, seed: UInt64) -> RulesOutcome {
        guard campaign.rulesPackID == pack.descriptor.id else { return .rejected(reason: "The active campaign and rules pack do not match.") }
        guard pack.descriptor.actionVerbs.contains(intent.verb.lowercased()) else { return .rejected(reason: "\(intent.verb) is not a declared action in \(pack.descriptor.displayName).") }
        let check = pack.descriptor.standardCheck
        let traitModifier = campaign.world.player?.traits[intent.trait, default: 0] ?? 0
        guard let roll = try? DiceEngine.roll(DiceExpression(count: check.count, sides: check.sides, modifier: check.modifier + traitModifier), seed: seed) else { return .rejected(reason: "The rules pack contains an invalid check.") }
        let band = resolutionBand(for: roll, target: intent.difficulty.target)
        let event = CampaignEvent(campaignID: campaign.id, kind: .actionResolved, payload: [
            "verb": intent.verb, "detail": intent.detail, "trait": intent.trait.rawValue,
            "target": String(intent.difficulty.target), "total": String(roll.total), "dice": roll.values.map(String.init).joined(separator: ","),
            "band": band.rawValue, "seed": String(seed)
        ])
        return .accepted(event)
    }

    private func resolutionBand(for roll: DiceRoll, target: Int) -> ResolutionBand {
        if roll.values.contains(20) { return .criticalSuccess }
        if roll.values.contains(1) { return .criticalComplication }
        if roll.total >= target { return .fullSuccess }
        if roll.total >= target - 2 { return .successWithCost }
        return .miss
    }
}
