import AetherTableCore
import Foundation

public protocol CampaignStore: Sendable { func load(id: CampaignID) async throws -> CampaignState?; func save(_ campaign: CampaignState) async throws }

public actor InMemoryCampaignStore: CampaignStore {
    private var campaigns: [CampaignID: CampaignState] = [:]
    public init() {}
    public func load(id: CampaignID) async throws -> CampaignState? { campaigns[id] }
    public func save(_ campaign: CampaignState) async throws { campaigns[campaign.id] = campaign }
}
