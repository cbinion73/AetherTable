import AetherTableCore

/// Owned encounter data for AetherTable’s first SRD-backed scene. The River
/// Shade is original AetherTable content; only its resolution mechanics come
/// from the separately attributed SRD pack.
public enum LanternBelowEncounter {
    public static let riverShadeID = "river-shade"
    public static let playerID = "player"

    public static func riverShadeAttack(targetID: String = playerID) -> SRD521AttackRequest {
        .init(
            attackerID: riverShadeID,
            targetID: targetID,
            ability: .dexterity,
            abilityScore: 14,
            proficiencyBonus: 2,
            isProficient: true,
            damage: .init(count: 1, sides: 6, modifier: 2)
        )
    }

    public enum Completion: Sendable {
        case victory
        case defeat

        public var narration: String {
            switch self {
            case .victory: "The River Shade dissolves into silver mist, leaving a brass tide-key and a whispered route to the flooded archive."
            case .defeat: "The river takes you to the bank. You wake at the lantern-keeper’s shelter with the Shade’s warning still in your ears."
            }
        }
    }

    /// Owned narrative consequences follow an authoritative encounter result.
    /// Neither an AI response nor UI state chooses the outcome.
    public static func completionEvents(campaignID: CampaignID, encounter: EncounterState) -> (completion: Completion, events: [CampaignEvent])? {
        guard encounter.status == .active else { return nil }
        let playersStanding = encounter.combatants.contains { ($0.team == .player || $0.team == .ally) && $0.hitPoints > 0 }
        let enemiesStanding = encounter.combatants.contains { $0.team == .enemy && $0.hitPoints > 0 }
        guard !playersStanding || !enemiesStanding else { return nil }

        if !enemiesStanding {
            return (.victory, [
                .init(campaignID: campaignID, kind: .encounterEnded, payload: ["outcome": "victory"]),
                .init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "lantern-below.riverShade", "value": "dispelled"]),
                .init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "reward.brassTideKey", "value": "claimed"]),
                .init(campaignID: campaignID, kind: .questUpdated, payload: ["stage": "archive", "objective": "Follow the brass tide-key to the flooded archive."]),
                .init(campaignID: campaignID, kind: .sceneEntered, payload: ["sceneID": "lantern-below.flooded-archive", "locationID": "emberwake.flooded-archive"])
            ])
        }

        return (.defeat, [
            .init(campaignID: campaignID, kind: .encounterEnded, payload: ["outcome": "defeat"]),
            .init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "lantern-below.riverShade", "value": "survived"]),
            .init(campaignID: campaignID, kind: .threatChanged, payload: ["delta": "1"]),
            .init(campaignID: campaignID, kind: .questUpdated, payload: ["stage": "recover", "objective": "Recover at the lantern-keeper’s shelter, then choose how to return to the bridge."]),
            .init(campaignID: campaignID, kind: .sceneEntered, payload: ["sceneID": "lantern-below.shelter", "locationID": "emberwake.lantern-shelter"])
        ])
    }
}
