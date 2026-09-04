import AetherTableCore
import DiceEngine
import Foundation

public struct PlayerIntent: Hashable, Sendable { public let verb: String; public let detail: String; public init(verb: String, detail: String) { self.verb = verb; self.detail = detail } }
public enum RulesOutcome: Sendable { case accepted(CampaignEvent); case rejected(reason: String) }

public struct RulesEngine: Sendable {
    public init() {}
    public func resolve(intent: PlayerIntent, in campaign: CampaignState, using pack: any RulesPack, seed: UInt64) -> RulesOutcome {
        guard campaign.rulesPackID == pack.descriptor.id else { return .rejected(reason: "The active campaign and rules pack do not match.") }
        guard pack.descriptor.actionVerbs.contains(intent.verb.lowercased()) else { return .rejected(reason: "\(intent.verb) is not a declared action in \(pack.descriptor.displayName).") }
        let roll = try? DiceEngine.roll(DiceExpression(count: 1, sides: 20, modifier: 0), seed: seed)
        let event = CampaignEvent(campaignID: campaign.id, kind: .actionResolved, payload: ["verb": intent.verb, "detail": intent.detail, "total": String(roll?.total ?? 0), "seed": String(seed)])
        return .accepted(event)
    }
}
