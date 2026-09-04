import AetherTableCore
import Foundation

public struct GMIntentProposal: Codable, Hashable, Sendable {
    public let verb: String
    public let detail: String
    public let narrationPrompt: String
    public init(verb: String, detail: String, narrationPrompt: String) { self.verb = verb; self.detail = detail; self.narrationPrompt = narrationPrompt }
}

public protocol GameMaster: Sendable { func proposeIntent(from playerText: String, campaign: CampaignState) async throws -> GMIntentProposal }

public enum GameMasterError: Error { case unavailable }

/// Integration boundary for Apple Foundation Models. A production implementation
/// uses guided generation and tool calls; rules and persistence remain outside the model.
public struct FoundationModelsGM: GameMaster {
    public init() {}
    public func proposeIntent(from playerText: String, campaign: CampaignState) async throws -> GMIntentProposal { throw GameMasterError.unavailable }
}
