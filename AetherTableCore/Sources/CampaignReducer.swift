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
        case .sceneStatusChanged:
            let sceneID = try required("sceneID", in: event)
            guard let status = SceneStatus(rawValue: try required("status", in: event)) else { throw CampaignReducerError.malformedPayload("status") }
            campaign.world.sceneProgress[sceneID] = status
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
        case .threatChanged:
            let delta = try integer("delta", in: event)
            campaign.world.threatClock.current = min(campaign.world.threatClock.maximum, max(0, campaign.world.threatClock.current + delta))
        case .questUpdated:
            campaign.world.quest.stage = try required("stage", in: event)
            campaign.world.quest.objective = try required("objective", in: event)
        case .choiceCommitted:
            campaign.world.facts[try required("key", in: event)] = try required("value", in: event)
        case .encounterStarted:
            guard campaign.world.encounter == nil || campaign.world.encounter?.status == .ended else { throw CampaignReducerError.encounterAlreadyActive }
            campaign.world.encounter = .init(id: try required("encounterID", in: event), title: try required("title", in: event))
        case .combatantJoined:
            try addCombatant(from: event, in: &campaign)
        case .turnStarted:
            try startTurn(from: event, in: &campaign)
        case .combatantDamaged:
            try damageCombatant(from: event, in: &campaign)
        case .combatantConditionChanged:
            try changeCombatantCondition(from: event, in: &campaign)
        case .encounterEnded:
            guard var encounter = campaign.world.encounter else { throw CampaignReducerError.missingEncounter }
            encounter.status = .ended
            encounter.activeCombatantID = nil
            campaign.world.encounter = encounter
        case .packStateSet:
            campaign.world.packState[try required("key", in: event)] = try required("value", in: event)
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

    private static func addCombatant(from event: CampaignEvent, in campaign: inout CampaignState) throws {
        guard var encounter = campaign.world.encounter, encounter.status == .active else { throw CampaignReducerError.missingEncounter }
        let id = try required("combatantID", in: event)
        guard !encounter.combatants.contains(where: { $0.id == id }) else { throw CampaignReducerError.duplicateCombatant }
        guard let team = EncounterCombatant.Team(rawValue: try required("team", in: event)) else { throw CampaignReducerError.malformedPayload("team") }
        let maximumHitPoints = try integer("maximumHitPoints", in: event)
        let armorClass = try integer("armorClass", in: event)
        guard maximumHitPoints > 0, armorClass > 0 else { throw CampaignReducerError.malformedPayload("combatant statistics") }
        encounter.combatants.append(.init(id: id, name: try required("name", in: event), team: team, initiative: try integer("initiative", in: event), maximumHitPoints: maximumHitPoints, armorClass: armorClass))
        encounter.combatants.sort { $0.initiative == $1.initiative ? $0.id < $1.id : $0.initiative > $1.initiative }
        campaign.world.encounter = encounter
    }

    private static func startTurn(from event: CampaignEvent, in campaign: inout CampaignState) throws {
        guard var encounter = campaign.world.encounter, encounter.status == .active else { throw CampaignReducerError.missingEncounter }
        let combatantID = try required("combatantID", in: event)
        guard encounter.combatants.contains(where: { $0.id == combatantID }) else { throw CampaignReducerError.missingCombatant }
        let round = try integer("round", in: event)
        guard round > 0 else { throw CampaignReducerError.malformedPayload("round") }
        encounter.round = round
        encounter.activeCombatantID = combatantID
        campaign.world.encounter = encounter
    }

    private static func damageCombatant(from event: CampaignEvent, in campaign: inout CampaignState) throws {
        guard var encounter = campaign.world.encounter, encounter.status == .active else { throw CampaignReducerError.missingEncounter }
        let combatantID = try required("combatantID", in: event)
        let damage = try integer("damage", in: event)
        guard damage >= 0, let index = encounter.combatants.firstIndex(where: { $0.id == combatantID }) else { throw CampaignReducerError.missingCombatant }
        encounter.combatants[index].hitPoints = max(0, encounter.combatants[index].hitPoints - damage)
        if encounter.combatants[index].hitPoints == 0 { encounter.combatants[index].conditions.insert("defeated") }
        campaign.world.encounter = encounter
    }

    private static func changeCombatantCondition(from event: CampaignEvent, in campaign: inout CampaignState) throws {
        guard var encounter = campaign.world.encounter else { throw CampaignReducerError.missingEncounter }
        let combatantID = try required("combatantID", in: event)
        guard let index = encounter.combatants.firstIndex(where: { $0.id == combatantID }) else { throw CampaignReducerError.missingCombatant }
        let condition = try required("condition", in: event)
        switch try required("operation", in: event) {
        case "add": encounter.combatants[index].conditions.insert(condition)
        case "remove": encounter.combatants[index].conditions.remove(condition)
        default: throw CampaignReducerError.malformedPayload("operation")
        }
        campaign.world.encounter = encounter
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
    case encounterAlreadyActive, missingEncounter, duplicateCombatant, missingCombatant
    case malformedPayload(String)
}
