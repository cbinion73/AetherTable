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
        .init(id: "study-key", title: "Study the tide-key", prompt: "I study the tide-key and the archive’s lockwork.", ability: .intelligence, difficultyClass: 13),
        .init(id: "force-seal", title: "Break the seal", prompt: "I force the swollen archive seal apart.", ability: .strength, difficultyClass: 15),
        .init(id: "speak-oath", title: "Speak the keeper’s oath", prompt: "I speak the old keeper’s oath to the water.", ability: .charisma, difficultyClass: 10)
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
            .init(campaignID: campaignID, kind: .questUpdated, payload: ["stage": "vault", "objective": "Descend through the archive to the sealed vault and learn who extinguished the Lantern Below."]),
            .init(campaignID: campaignID, kind: .sceneStatusChanged, payload: ["sceneID": sceneID, "status": "completed"])
        ]
        if !succeeded {
            events.append(.init(campaignID: campaignID, kind: .threatChanged, payload: ["delta": "1"]))
            events.append(.init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "lantern-below.archiveAlarm", "value": "raised"]))
        }
        return events
    }
}

public enum FloodedArchiveError: Error, Equatable { case invalidChoice }
