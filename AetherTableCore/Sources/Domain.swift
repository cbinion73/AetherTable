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

    public enum Kind: String, Codable, Sendable { case campaignCreated, actionResolved, noteAdded }

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

    public init(id: CampaignID = CampaignID(), title: String, rulesPackID: RulesPackID, recap: String = "A new story waits.", events: [CampaignEvent] = []) {
        self.id = id; self.title = title; self.rulesPackID = rulesPackID; self.recap = recap; self.events = events
    }
}

public struct RulesPackDescriptor: Identifiable, Codable, Hashable, Sendable {
    public var id: RulesPackID
    public var version: String
    public var displayName: String
    public var mechanicFamily: String
    public var standardCheck: DiceSpecification
    public var actionVerbs: [String]

    public init(id: RulesPackID, version: String, displayName: String, mechanicFamily: String, standardCheck: DiceSpecification, actionVerbs: [String]) {
        self.id = id; self.version = version; self.displayName = displayName; self.mechanicFamily = mechanicFamily; self.standardCheck = standardCheck; self.actionVerbs = actionVerbs
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
    mutating func apply(_ event: CampaignEvent) {
        precondition(event.campaignID == id, "An event may only be applied to its own campaign.")
        guard !events.contains(where: { $0.id == event.id }) else { return }
        events.append(event)
        if event.kind == .actionResolved, let detail = event.payload["detail"], let total = event.payload["total"] {
            recap = "You last \(event.payload["verb"] ?? "acted") to \(detail). The authoritative roll was \(total)."
        }
    }
}
