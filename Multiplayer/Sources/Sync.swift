import AetherTableCore
import Foundation

public protocol CampaignEventTransport: Sendable {
    func publish(_ event: CampaignEvent) async throws
    func events(for campaignID: CampaignID) async throws -> [CampaignEvent]
}

public enum SyncMode: String, Sendable { case solo, shared }
