import AetherTableCore
import Foundation

public struct FloodedArchiveChoice: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let prompt: String
    public let ability: SRD521Ability
    public let difficultyClass: Int
}

/// The second owned text scene. It relies only on the SRD ability-check
/// mechanics and lets narrative consequences stay original to AetherTable.
public enum LanternBelowFloodedArchive {
    public static let sceneID = "lantern-below.flooded-archive"
    public static let choices: [FloodedArchiveChoice] = [
        .init(id: "oren-ledger", title: "Ask Oren for the ledger", prompt: "I press Oren to show me the redacted founding ledger.", ability: .charisma, difficultyClass: 13),
        .init(id: "waterworks", title: "Enter through the waterworks", prompt: "I trace the submerged waterworks to the archive’s forgotten plates.", ability: .intelligence, difficultyClass: 13),
        .init(id: "sera-memory", title: "Follow Sera’s memory", prompt: "I follow Sera’s memory to the keeper’s hidden record.", ability: .wisdom, difficultyClass: 10)
    ]

    public static func resolve(campaignID: CampaignID, profile: SRD521CharacterProfile, choiceID: String, die: Int) throws -> (result: SRD521TestResult, event: CampaignEvent) {
        guard let choice = choices.first(where: { $0.id == choiceID }), let score = profile.abilityScores[choice.ability] else { throw FloodedArchiveError.invalidChoice }
        let result = try SRD521CoreMechanics.resolve(
            request: .init(kind: .abilityCheck, ability: choice.ability, abilityScore: score, proficiencyBonus: profile.proficiencyBonus, isProficient: false, target: choice.difficultyClass),
            dice: [die]
        )
        return (result, .init(campaignID: campaignID, kind: .actionResolved, payload: [
            "verb": "ability check", "detail": choice.prompt, "ruleID": "srd-5.2.1.playing-the-game.ability-checks", "choiceID": choice.id,
            "ability": choice.ability.rawValue, "target": String(choice.difficultyClass), "total": String(result.total), "dice": String(die), "outcome": result.outcome.rawValue
        ]))
    }

    public static func consequenceEvents(campaignID: CampaignID, choiceID: String, result: SRD521TestResult) throws -> [CampaignEvent] {
        guard choices.contains(where: { $0.id == choiceID }) else { throw FloodedArchiveError.invalidChoice }
        let succeeded = result.outcome == .success
        let route = succeeded ? "clear" : "costly"
        var events: [CampaignEvent] = [
            .init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "lantern-below.archiveRoute", "value": route]),
            .init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "lantern-below.archiveChoice", "value": choiceID]),
            .init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "town.truth", "value": "vaultDebt"]),
            .init(campaignID: campaignID, kind: .questUpdated, payload: ["stage": "vault", "objective": "Descend through the archive to the sealed vault and learn who extinguished the Lantern Below."]),
            .init(campaignID: campaignID, kind: .sceneStatusChanged, payload: ["sceneID": sceneID, "status": "completed"]),
            .init(campaignID: campaignID, kind: .sceneEntered, payload: ["sceneID": LanternBelowVault.sceneID, "locationID": "emberwake.vault"])
        ]
        switch choiceID {
        case "oren-ledger":
            events.append(.init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "clue.foundingNames", "value": "true"]))
            events.append(.init(campaignID: campaignID, kind: .relationshipChanged, payload: ["npcID": "npc.oren", "delta": succeeded ? "1" : "-1"]))
        case "waterworks":
            events.append(.init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "clue.foundingNames", "value": "true"]))
        case "sera-memory":
            events.append(.init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "clue.brotherNote", "value": "true"]))
            events.append(.init(campaignID: campaignID, kind: .relationshipChanged, payload: ["npcID": "npc.sera", "delta": "1"]))
        default:
            throw FloodedArchiveError.invalidChoice
        }
        if !succeeded {
            events.append(.init(campaignID: campaignID, kind: .threatChanged, payload: ["delta": "1"]))
            events.append(.init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "lantern-below.archiveAlarm", "value": "raised"]))
        }
        return events
    }
}

public enum FloodedArchiveError: Error, Equatable { case invalidChoice }
