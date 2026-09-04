import AetherTableCore
import RulesEngine

public struct SceneChoice: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let prompt: String
    public let trait: CharacterTrait
    public let difficulty: CheckDifficulty
    public init(id: String, title: String, prompt: String, trait: CharacterTrait, difficulty: CheckDifficulty) {
        self.id = id; self.title = title; self.prompt = prompt; self.trait = trait; self.difficulty = difficulty
    }
}

/// Executable content for the first AetherTable scene. Every branch creates a clue;
/// a bad roll changes the cost, never whether the campaign can continue.
public enum LanternBelowSceneOne {
    public static let id = "lantern-below.dark-bridge"
    public static let introduction = "At dawn, Emberwake's river runs uphill. Beneath Old Bridge, the Lantern Below is dark for the first time in living memory."
    public static let choices: [SceneChoice] = [
        .init(id: "climb", title: "Climb below the bridge", prompt: "I climb down to inspect the dark lantern.", trait: .might, difficulty: .risky),
        .init(id: "study", title: "Study the current", prompt: "I study why the river is flowing backward.", trait: .wits, difficulty: .steady),
        .init(id: "calm", title: "Calm the crowd", prompt: "I steady the frightened crowd and speak with Sera.", trait: .presence, difficulty: .risky),
        .init(id: "boat", title: "Retrieve the paper boat", prompt: "I retrieve the child's paper boat from the upstream current.", trait: .wits, difficulty: .steady)
    ]

    public static func enterEvents(for campaignID: CampaignID) -> [CampaignEvent] {
        [CampaignEvent(campaignID: campaignID, kind: .sceneEntered, payload: ["sceneID": id, "locationID": "emberwake.bridge"])]
    }

    public static func intent(for choice: SceneChoice) -> PlayerIntent {
        PlayerIntent(verb: "attempt", detail: choice.prompt, trait: choice.trait, difficulty: choice.difficulty)
    }

    public static func consequenceEvents(choiceID: String, resolved event: CampaignEvent) throws -> [CampaignEvent] {
        guard let band = event.payload["band"].flatMap(ResolutionBand.init(rawValue:)) else { throw LanternBelowSceneError.missingResolution }
        let campaignID = event.campaignID
        let clue: String
        let relationshipDelta: Int
        switch choiceID {
        case "climb": clue = "clue.brassShard"; relationshipDelta = 1
        case "study": clue = "clue.archiveCurrent"; relationshipDelta = 0
        case "calm": clue = "clue.stairDrawing"; relationshipDelta = 1
        case "boat": clue = "clue.stairDrawing"; relationshipDelta = 0
        default: throw LanternBelowSceneError.unknownChoice
        }
        var events = [
            CampaignEvent(campaignID: campaignID, kind: .worldFactSet, payload: ["key": clue, "value": "true"]),
            CampaignEvent(campaignID: campaignID, kind: .relationshipChanged, payload: ["npcID": "npc.sera", "delta": String(relationshipDelta)]),
            CampaignEvent(campaignID: campaignID, kind: .sceneStatusChanged, payload: ["sceneID": id, "status": "completed"]),
            CampaignEvent(campaignID: campaignID, kind: .questUpdated, payload: ["stage": "archive", "objective": "Find why the Lantern Below was extinguished."])
        ]
        switch band {
        case .fullSuccess, .criticalSuccess:
            break
        case .successWithCost:
            events.append(CampaignEvent(campaignID: campaignID, kind: .conditionChanged, payload: ["condition": choiceID == "climb" ? "winded" : "exposed", "operation": "add"]))
        case .miss, .criticalComplication:
            events.append(CampaignEvent(campaignID: campaignID, kind: .threatChanged, payload: ["delta": "1"]))
            events.append(CampaignEvent(campaignID: campaignID, kind: .conditionChanged, payload: ["condition": choiceID == "study" ? "marked" : "exposed", "operation": "add"]))
        }
        return events
    }
}

public enum LanternBelowSceneError: Error, Equatable, Sendable { case missingResolution, unknownChoice }
