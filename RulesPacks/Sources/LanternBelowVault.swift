import AetherTableCore
import Foundation

public struct LanternVaultChoice: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let prompt: String
    public let ability: SRD521Ability
    public let difficultyClass: Int
    public let requiresVaultTruth: Bool
}

/// The final scene is an owned story decision. SRD 5.2.1 supplies only the
/// ability-check procedure; the choices and world consequences belong to AetherTable.
public enum LanternBelowVault {
    public static let sceneID = "lantern-below.vault"
    public static let choices: [LanternVaultChoice] = [
        .init(id: "renew", title: "Renew the promise", prompt: "I offer a new vow at the Lantern’s threshold.", ability: .charisma, difficultyClass: 16, requiresVaultTruth: false),
        .init(id: "reveal", title: "Reveal the debt", prompt: "I name Emberwake’s debt before the bound keeper.", ability: .intelligence, difficultyClass: 13, requiresVaultTruth: true),
        .init(id: "break", title: "Break the binding", prompt: "I break the old binding and accept what the river changes.", ability: .strength, difficultyClass: 16, requiresVaultTruth: false),
        .init(id: "bargain", title: "Bargain for time", prompt: "I bargain for one season of calm and record its price.", ability: .charisma, difficultyClass: 13, requiresVaultTruth: false)
    ]

    public static func resolve(campaignID: CampaignID, campaign: CampaignState, profile: SRD521CharacterProfile, choiceID: String, die: Int) throws -> (result: SRD521TestResult, event: CampaignEvent) {
        guard let choice = choices.first(where: { $0.id == choiceID }), let score = profile.abilityScores[choice.ability] else { throw LanternVaultError.invalidChoice }
        guard !choice.requiresVaultTruth || campaign.world.facts["town.truth"] == "vaultDebt" else { throw LanternVaultError.missingPrerequisite }
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
        guard choices.contains(where: { $0.id == choiceID }) else { throw LanternVaultError.invalidChoice }
        let outcome = result.outcome == .success ? "resolved" : "costly"
        let vaultStatus: String
        let lanternStatus: String
        let relationship: String
        let nextQuestion: String
        switch choiceID {
        case "renew":
            vaultStatus = "renewed"; lanternStatus = "lit"; relationship = "bound"; nextQuestion = "What does Emberwake owe when its new promise comes due?"
        case "reveal":
            vaultStatus = "revealed"; lanternStatus = "dark"; relationship = "truth-told"; nextQuestion = "Who will carry the truth when Emberwake learns what it buried?"
        case "break":
            vaultStatus = "broken"; lanternStatus = "dark"; relationship = "freed"; nextQuestion = "How will Emberwake rebuild after the river changes course?"
        case "bargain":
            vaultStatus = "deferred"; lanternStatus = "flickering"; relationship = "bargained"; nextQuestion = "What will the promised season of calm cost when it ends?"
        default:
            throw LanternVaultError.invalidChoice
        }
        var events: [CampaignEvent] = [
            .init(campaignID: campaignID, kind: .choiceCommitted, payload: ["key": "lantern-below.vaultChoice", "value": choiceID]),
            .init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "vault.status", "value": vaultStatus]),
            .init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "lantern.status", "value": lanternStatus]),
            .init(campaignID: campaignID, kind: .worldFactSet, payload: ["key": "lantern-below.vaultOutcome", "value": outcome]),
            .init(campaignID: campaignID, kind: .relationshipChanged, payload: ["npcID": "npc.nym", "delta": relationship == "freed" ? "2" : "1"]),
            .init(campaignID: campaignID, kind: .questUpdated, payload: ["stage": "complete", "objective": nextQuestion]),
            .init(campaignID: campaignID, kind: .sceneStatusChanged, payload: ["sceneID": sceneID, "status": "completed"])
        ]
        if result.outcome == .failure {
            events.append(.init(campaignID: campaignID, kind: .threatChanged, payload: ["delta": "1"]))
        }
        return events
    }
}

public enum LanternVaultError: Error, Equatable { case invalidChoice, missingPrerequisite }
