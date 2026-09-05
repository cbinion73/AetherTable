import Foundation

public struct CampaignID: Hashable, Codable, Sendable, RawRepresentable {
    public let rawValue: UUID
    public init(rawValue: UUID = UUID()) { self.rawValue = rawValue }
}

public struct RulesPackID: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.init(rawValue: value) }
}

public struct CampaignEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let campaignID: CampaignID
    public let createdAt: Date
    public let kind: Kind
    public let payload: [String: String]

    public enum Kind: String, Codable, Sendable {
        case campaignCreated, characterCreated, sceneEntered, sceneStatusChanged, intentProposed, actionResolved, worldFactSet
        case resourceChanged, conditionChanged, relationshipChanged, threatChanged, questUpdated, choiceCommitted, noteAdded
    }

    public init(id: UUID = UUID(), campaignID: CampaignID, createdAt: Date = .now, kind: Kind, payload: [String: String]) {
        self.id = id; self.campaignID = campaignID; self.createdAt = createdAt; self.kind = kind; self.payload = payload
    }
}

public struct CampaignState: Codable, Hashable, Sendable {
    public let id: CampaignID
    public var title: String
    public var rulesPackID: RulesPackID
    public var recap: String
    public var events: [CampaignEvent]
    public var world: WorldState

    public init(id: CampaignID = CampaignID(), title: String, rulesPackID: RulesPackID, recap: String = "A new story waits.", events: [CampaignEvent] = [], world: WorldState = .init()) {
        self.id = id; self.title = title; self.rulesPackID = rulesPackID; self.recap = recap; self.events = events; self.world = world
    }
}

public struct WorldState: Codable, Hashable, Sendable {
    public var locationID: String
    public var quest: QuestState
    public var facts: [String: String]
    public var relationships: [String: Int]
    public var sceneProgress: [String: SceneStatus]
    public var threatClock: ThreatClock
    public var player: CharacterSheet?

    public init(
        locationID: String = "emberwake.square",
        quest: QuestState = .init(id: "lantern-below", stage: "opening", objective: "Learn why the Lantern Below was extinguished."),
        facts: [String: String] = ["lantern.status": "extinguished", "river.direction": "upstream", "vault.status": "sealed", "town.truth": "unknown"],
        relationships: [String: Int] = ["npc.sera": 0, "npc.oren": 0, "npc.nym": 0],
        sceneProgress: [String: SceneStatus] = [:],
        threatClock: ThreatClock = .init(current: 0, maximum: 4),
        player: CharacterSheet? = nil
    ) {
        self.locationID = locationID; self.quest = quest; self.facts = facts; self.relationships = relationships; self.sceneProgress = sceneProgress; self.threatClock = threatClock; self.player = player
    }
}

public struct QuestState: Codable, Hashable, Sendable {
    public var id: String
    public var stage: String
    public var objective: String
    public init(id: String, stage: String, objective: String) { self.id = id; self.stage = stage; self.objective = objective }
}

public enum SceneStatus: String, Codable, Hashable, Sendable { case locked, available, active, completed }

public struct ThreatClock: Codable, Hashable, Sendable {
    public var current: Int
    public var maximum: Int
    public init(current: Int, maximum: Int) { self.current = current; self.maximum = maximum }
}

public enum CharacterTrait: String, CaseIterable, Codable, Hashable, Sendable { case might, wits, presence }

public enum CharacterCondition: String, CaseIterable, Codable, Hashable, Sendable { case shaken, exposed, winded, marked, down }

public struct CharacterSheet: Codable, Hashable, Sendable {
    public var name: String
    public var archetype: String
    public var definingDetail: String
    public var traits: [CharacterTrait: Int]
    public var health: Int
    public var maximumHealth: Int
    public var resolve: Int
    public var maximumResolve: Int
    public var inventory: [String]
    public var conditions: Set<CharacterCondition>

    public init(name: String, archetype: String, definingDetail: String, favoredTrait: CharacterTrait) {
        self.name = name; self.archetype = archetype; self.definingDetail = definingDetail
        self.traits = Dictionary(uniqueKeysWithValues: CharacterTrait.allCases.map { ($0, $0 == favoredTrait ? 2 : 0) })
        self.health = 6; self.maximumHealth = 6; self.resolve = 3; self.maximumResolve = 3
        self.inventory = ["Personal token", "Travel pack", "10 silver marks"]
        self.conditions = []
    }
}

public struct RulesPackDescriptor: Identifiable, Codable, Hashable, Sendable {
    public var id: RulesPackID
    public var version: String
    public var displayName: String
    public var mechanicFamily: String
    public var standardCheck: DiceSpecification
    public var actionVerbs: [String]
    public var license: RulesPackLicense?

    public init(id: RulesPackID, version: String, displayName: String, mechanicFamily: String, standardCheck: DiceSpecification, actionVerbs: [String], license: RulesPackLicense? = nil) {
        self.id = id; self.version = version; self.displayName = displayName; self.mechanicFamily = mechanicFamily; self.standardCheck = standardCheck; self.actionVerbs = actionVerbs; self.license = license
    }
}

/// A visible provenance contract for any pack that contains third-party rules.
/// It travels with the pack instead of being buried in a release note.
public struct RulesPackLicense: Codable, Hashable, Sendable {
    public let sourceName: String
    public let sourceVersion: String
    public let licenseName: String
    public let sourceURL: URL
    public let attribution: String

    public init(sourceName: String, sourceVersion: String, licenseName: String, sourceURL: URL, attribution: String) {
        self.sourceName = sourceName; self.sourceVersion = sourceVersion; self.licenseName = licenseName; self.sourceURL = sourceURL; self.attribution = attribution
    }
}

public struct DiceSpecification: Codable, Hashable, Sendable {
    public let count: Int
    public let sides: Int
    public let modifier: Int
    public init(count: Int, sides: Int, modifier: Int = 0) { self.count = count; self.sides = sides; self.modifier = modifier }
}

public protocol RulesPack: Sendable {
    var descriptor: RulesPackDescriptor { get }
}

public extension CampaignState {
    mutating func apply(_ event: CampaignEvent) throws {
        try CampaignReducer.apply(event, to: &self)
    }
}
