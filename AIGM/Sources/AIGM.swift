import AetherTableCore
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public struct GMIntentProposal: Codable, Hashable, Sendable {
    public let verb: String
    public let detail: String
    public let narrationPrompt: String
    public init(verb: String, detail: String, narrationPrompt: String) { self.verb = verb; self.detail = detail; self.narrationPrompt = narrationPrompt }
}

public protocol GameMaster: Sendable {
    func proposeIntent(from playerText: String, campaign: CampaignState) async throws -> GMIntentProposal
    /// Creates player-facing prose from facts already recorded by the engine.
    /// The returned text is never applied as campaign state.
    func narrate(resolved event: CampaignEvent, campaign: CampaignState) async throws -> String
}

public enum GameMasterError: LocalizedError { case unavailable(String)
    public var errorDescription: String? { switch self { case .unavailable(let reason): "Apple Intelligence GM unavailable: \(reason)" } }
}

/// Integration boundary for Apple Foundation Models. A production implementation
/// uses guided generation and tool calls; rules and persistence remain outside the model.
public struct FoundationModelsGM: GameMaster {
    public init() {}
    public func proposeIntent(from playerText: String, campaign: CampaignState) async throws -> GMIntentProposal {
        try await proposeIntent(from: playerText, campaign: campaign, availableActions: ["attempt"])
    }
    public func proposeIntent(from playerText: String, campaign: CampaignState, availableActions: [String]) async throws -> GMIntentProposal {
        guard !availableActions.isEmpty else { throw GameMasterError.unavailable("No actions available.") }
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { throw GameMasterError.unavailable("Apple Intelligence is not ready on this device.") }
        let session = LanguageModelSession(model: model, instructions: """
        You are a tabletop roleplaying game facilitator. You propose intent and narration only.
        You do not decide rules, outcomes, dice results, inventory, hit points, or world state.
        Use one of the supplied action verbs exactly. Keep narration under 60 words.
        """)
        let packActions = availableActions.joined(separator: ", ")
        let response = try await session.respond(
            to: "Campaign recap: \(campaign.recap)\nAvailable action verbs: \(packActions)\nPlayer says: \(playerText)\nReturn a safe proposed verb, concise detail, and narration prompt.",
            generating: GeneratedGMProposal.self
        )
        guard availableActions.contains(response.content.verb.lowercased()) else { throw GameMasterError.unavailable("Intent does not match an available action.") }
        return GMIntentProposal(verb: response.content.verb.lowercased(), detail: response.content.detail, narrationPrompt: response.content.narration)
        #else
        throw GameMasterError.unavailable("Foundation Models is not available in this SDK.")
        #endif
    }

    public func narrate(resolved event: CampaignEvent, campaign: CampaignState) async throws -> String {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { throw GameMasterError.unavailable("Apple Intelligence is not ready on this device.") }
        let session = LanguageModelSession(model: model, instructions: """
        You are the conversational voice of a tabletop roleplaying game.
        Narrate only facts in the supplied resolved event and campaign snapshot.
        Never invent a rule, roll, item, creature fact, injury, choice, or world-state change.
        Do not say that a player succeeded when the resolved outcome says failure.
        Write one evocative, second-person response of 80 words or fewer.
        """)
        let facts = campaign.world.facts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        let response = try await session.respond(
            to: "Resolved event: \(event.kind.rawValue), \(event.payload)\nCampaign recap: \(campaign.recap)\nLocation: \(campaign.world.locationID)\nObjective: \(campaign.world.quest.objective)\nRecorded facts: \(facts)",
            generating: GeneratedGMNarration.self
        )
        return response.content.text
        #else
        throw GameMasterError.unavailable("Foundation Models is not available in this SDK.")
        #endif
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable(description: "A proposed tabletop intent. It never declares an outcome or dice result.")
private struct GeneratedGMProposal {
    @Guide(description: "One short action verb supplied by the player or a conservative default such as attempt.") var verb: String
    @Guide(description: "A concise description of what the player is attempting.") var detail: String
    @Guide(description: "A 60-word maximum prompt for narration after the deterministic engine resolves the action.") var narration: String
}

@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
@Generable(description: "A player-facing narration of already-resolved campaign facts.")
private struct GeneratedGMNarration {
    @Guide(description: "A fact-bound, second-person response of 80 words or fewer. It contains no new rules or world facts.") var text: String
}
#endif
