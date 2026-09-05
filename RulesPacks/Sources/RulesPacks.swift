import AetherTableCore
import Foundation

public struct DataRulesPack: RulesPack, Sendable {
    public let descriptor: RulesPackDescriptor
    public init(_ descriptor: RulesPackDescriptor) { self.descriptor = descriptor }
}

public enum BuiltInRulesPacks {
    public static let all: [DataRulesPack] = [
        DataRulesPack(.init(id: "d20-fantasy", version: "0.1.0", displayName: "D20 Fantasy Prototype", mechanicFamily: "d20", standardCheck: .init(count: 1, sides: 20), actionVerbs: ["attempt", "attack", "investigate", "negotiate"])),
        DataRulesPack(.init(id: "momentum-2d20", version: "0.1.0", displayName: "Momentum 2D20 Prototype", mechanicFamily: "2d20", standardCheck: .init(count: 2, sides: 20), actionVerbs: ["attempt", "scan", "negotiate", "maneuver"])),
        DataRulesPack(.init(id: "heroic-pool", version: "0.1.0", displayName: "Heroic Pool Prototype", mechanicFamily: "dice pool", standardCheck: .init(count: 4, sides: 6), actionVerbs: ["attempt", "defend", "create", "overcome"]))
    ]

    /// Third-party rules references stay separate from player-ready, owned packs.
    /// Promoting one into `all` requires its own mechanics and conformance gate.
    public static let referenceOnly: [RulesPackDescriptor] = [SRD521RulesPack.descriptor]
}
