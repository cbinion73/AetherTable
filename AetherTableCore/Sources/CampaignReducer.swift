import Foundation

/// The sole authority that turns a recorded event into campaign state.
/// Narrative systems may read its result; they may not bypass it.
public enum CampaignReducer {
    public static func apply(_ event: CampaignEvent, to campaign: inout CampaignState) throws {
        guard event.campaignID == campaign.id else { throw CampaignReducerError.wrongCampaign }
        guard !campaign.events.contains(where: { $0.id == event.id }) else { return } // sync-safe idempotency

        switch event.kind {
        case .campaignCreated, .intentProposed, .noteAdded:
            break
        case .characterCreated:
            try createCharacter(from: event, in: &campaign)
        case .sceneEntered:
            let sceneID = try required("sceneID", in: event)
            campaign.world.sceneProgress[sceneID] = .active
            if let locationID = event.payload["locationID"] { campaign.world.locationID = locationID }
        case .actionResolved:
            let detail = try required("detail", in: event)
            let total = try required("total", in: event)
            campaign.recap = "You last \(event.payload["verb"] ?? "acted") to \(detail). The authoritative roll was \(total)."
        case .worldFactSet:
            campaign.world.facts[try required("key", in: event)] = try required("value", in: event)
        case .resourceChanged:
            try changeResource(from: event, in: &campaign)
        case .conditionChanged:
            try changeCondition(from: event, in: &campaign)
        case .relationshipChanged:
            let npcID = try required("npcID", in: event)
            let delta = try integer("delta", in: event)
            let oldValue = campaign.world.relationships[npcID, default: 0]
            campaign.world.relationships[npcID] = min(2, max(-2, oldValue + delta))
        case .questUpdated:
            campaign.world.quest.stage = try required("stage", in: event)
            campaign.world.quest.objective = try required("objective", in: event)
        case .choiceCommitted:
            campaign.world.facts[try required("key", in: event)] = try required("value", in: event)
        }

        campaign.events.append(event)
    }

    private static func createCharacter(from event: CampaignEvent, in campaign: inout CampaignState) throws {
        guard campaign.world.player == nil else { throw CampaignReducerError.characterAlreadyExists }
        let favoredTrait = CharacterTrait(rawValue: try required("favoredTrait", in: event))
        guard let favoredTrait else { throw CampaignReducerError.invalidTrait }
        campaign.world.player = CharacterSheet(
            name: try required("name", in: event),
            archetype: try required("archetype", in: event),
            definingDetail: event.payload["definingDetail", default: ""],
            favoredTrait: favoredTrait
        )
    }

    private static func changeResource(from event: CampaignEvent, in campaign: inout CampaignState) throws {
        guard var player = campaign.world.player else { throw CampaignReducerError.missingCharacter }
        let resource = try required("resource", in: event)
        let delta = try integer("delta", in: event)
        switch resource {
        case "health": player.health = min(player.maximumHealth, max(0, player.health + delta))
        case "resolve": player.resolve = min(player.maximumResolve, max(0, player.resolve + delta))
        default: throw CampaignReducerError.unknownResource
        }
        if player.health == 0 { player.conditions.insert(.down) }
        campaign.world.player = player
    }

    private static func changeCondition(from event: CampaignEvent, in campaign: inout CampaignState) throws {
        guard var player = campaign.world.player else { throw CampaignReducerError.missingCharacter }
        guard let condition = CharacterCondition(rawValue: try required("condition", in: event)) else { throw CampaignReducerError.invalidCondition }
        switch try required("operation", in: event) {
        case "add": player.conditions.insert(condition)
        case "remove": player.conditions.remove(condition)
        default: throw CampaignReducerError.malformedPayload("operation")
        }
        campaign.world.player = player
    }

    private static func required(_ key: String, in event: CampaignEvent) throws -> String {
        guard let value = event.payload[key], !value.isEmpty else { throw CampaignReducerError.malformedPayload(key) }
        return value
    }

    private static func integer(_ key: String, in event: CampaignEvent) throws -> Int {
        guard let value = event.payload[key], let integer = Int(value) else { throw CampaignReducerError.malformedPayload(key) }
        return integer
    }
}

public enum CampaignReducerError: Error, Equatable, Sendable {
    case wrongCampaign, characterAlreadyExists, missingCharacter, invalidTrait, invalidCondition, unknownResource
    case malformedPayload(String)
}
