import AetherTableCore
import DiceEngine
import Foundation

public enum SoloAction: Hashable, Sendable { case attack, enemyTurn, secondWind, recover, archive(String), vault(String) }
public enum SoloCampaignError: LocalizedError {
    case unavailableAction, emptyNote
    public var errorDescription: String? { switch self { case .unavailableAction: "That action is no longer available. Your saved story has not changed."; case .emptyNote: "Write a note before saving." } }
}

/// An entire turn is prepared as a value. The caller must save it before publishing it.
public enum SoloCampaign {
    public static func create(name: String) throws -> CampaignState {
        let profile = try SRD521QuickstartCharacter.guardian(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
        var state = CampaignState(title: "The Lantern Below", rulesPackID: SRD521RulesPack.descriptor.id)
        try state.apply(profile.stateEvent(campaignID: state.id))
        try state.apply(.init(campaignID: state.id, kind: .sceneEntered, payload: ["sceneID": "lantern-below.bridge", "locationID": "emberwake.old-bridge"]))
        try state.apply(.init(campaignID: state.id, kind: .questUpdated, payload: ["stage": "bridge", "objective": "Drive back the River Shade and find a way beneath Emberwake."]))
        for event in SRD521EncounterEngine.startEvents(campaignID: state.id, encounterID: "emberwake.river-shade", title: "Dark Beneath the Bridge", combatants: [
            .init(id: "player", name: profile.name, team: .player, initiative: 14, maximumHitPoints: profile.maximumHitPoints, armorClass: profile.armorClass),
            .init(id: "river-shade", name: "River Shade", team: .enemy, initiative: 9, maximumHitPoints: 20, armorClass: 12)
        ]) { try state.apply(event) }
        state.recap = "Beneath Old Bridge, the current runs the wrong way. A pale shape rises between you and a door set into the river wall. Your hand closes around your longsword."
        return state
    }

    public static func isAvailable(_ action: SoloAction, in state: CampaignState) -> Bool {
        if let encounter = state.world.encounter, encounter.status == .active {
            switch action {
            case .attack: return encounter.activeCombatantID == "player"
            case .enemyTurn: return encounter.activeCombatantID == "river-shade"
            case .secondWind: return encounter.activeCombatantID == "player" && secondWindUses(in: state) > 0 && state.world.packState["solo.secondWindRound"] != String(encounter.round)
            default: return false
            }
        }
        switch action {
        case .recover: return state.world.quest.stage == "recover"
        case .archive(let id): return state.world.quest.stage == "archive" && LanternBelowFloodedArchive.choices.contains { $0.id == id }
        case .vault(let id): return state.world.quest.stage == "vault" && LanternBelowVault.choices.contains { $0.id == id && (!$0.requiresVaultTruth || state.world.facts["town.truth"] == "vaultDebt") }
        default: return false
        }
    }

    public static func resolve(_ action: SoloAction, in original: CampaignState, seed: UInt64) throws -> CampaignState {
        guard isAvailable(action, in: original) else { throw SoloCampaignError.unavailableAction }
        var state = original
        let profile = try SRD521CharacterProfile.from(campaign: state)
        switch action {
        case .secondWind:
            guard let encounter = state.world.encounter else { throw SoloCampaignError.unavailableAction }
            let die = try DiceEngine.roll(.init(count: 1, sides: 10), seed: seed).values[0]
            let before = hitPoints(in: state)
            try state.apply(.init(campaignID: state.id, kind: .combatantHealed, payload: ["combatantID": "player", "healing": String(die + profile.level), "dice": String(die), "modifier": String(profile.level), "seed": String(seed), "ruleID": "srd-5.2.1.fighter.second-wind"]))
            try state.apply(.init(campaignID: state.id, kind: .packStateSet, payload: ["key": "solo.secondWindUses", "value": String(secondWindUses(in: state) - 1)]))
            try state.apply(.init(campaignID: state.id, kind: .packStateSet, payload: ["key": "solo.secondWindRound", "value": String(encounter.round)]))
            state.recap = "You steady your breathing and draw on your reserves. Second Wind restores \(hitPoints(in: state) - before) hit points (d10: \(die) + \(profile.level), capped at \(profile.maximumHitPoints)). Your longsword action remains available."
        case .attack, .enemyTurn:
            guard let encounter = state.world.encounter else { throw SoloCampaignError.unavailableAction }
            let request = action == .attack ? try profile.attackRequest(attackID: "longsword", targetID: "river-shade") : LanternBelowEncounter.riverShadeAttack()
            let result = try SRD521EncounterEngine.resolveAttack(campaignID: state.id, in: encounter, request: request, seed: seed)
            for event in result.events { try state.apply(event) }
            if let updated = state.world.encounter, let completion = LanternBelowEncounter.completionEvents(campaignID: state.id, encounter: updated) {
                for event in completion.events { try state.apply(event) }
                state.recap = completion.completion.narration
            } else if let updated = state.world.encounter {
                try state.apply(SRD521EncounterEngine.nextTurnEvent(campaignID: state.id, encounter: updated))
                let subject = action == .attack ? "Your longsword" : "The Shade’s cold grasp"
                state.recap = result.damage > 0 ? "\(subject) strikes home for \(result.damage) damage. Water scatters across the stone. The struggle beneath Old Bridge continues." : "\(subject) finds no opening. The river swirls around your boots as the fight continues."
            }
        case .archive(let id):
            let die = try DiceEngine.roll(.init(count: 1, sides: 20), seed: seed).values[0]
            let result = try LanternBelowFloodedArchive.resolve(campaignID: state.id, profile: profile, choiceID: id, die: die)
            try state.apply(audited(result.event, seed: seed, result: result.result))
            for event in try LanternBelowFloodedArchive.consequenceEvents(campaignID: state.id, choiceID: id, result: result.result) { try state.apply(event) }
            let route = id == "oren-ledger" ? "Oren opens the founding ledger. Beneath the redactions, a promise remains." : id == "waterworks" ? "You find names cut into the submerged plates, older than the town above." : "Sera leads you to a hidden record: her brother’s note preserved in oilcloth."
            state.recap = route + " Emberwake bound a keeper to hold back the river, then buried its debt. A stair descends to Nym’s vault." + (result.result.outcome == .success ? " You reach it quietly." : " An alarm rings through the water; you reach the truth at a cost.")
        case .vault(let id):
            let die = try DiceEngine.roll(.init(count: 1, sides: 20), seed: seed).values[0]
            let result = try LanternBelowVault.resolve(campaignID: state.id, campaign: state, profile: profile, choiceID: id, die: die)
            try state.apply(audited(result.event, seed: seed, result: result.result))
            for event in try LanternBelowVault.consequenceEvents(campaignID: state.id, choiceID: id, result: result.result) { try state.apply(event) }
            let ending: String
            switch id {
            case "renew": ending = "You speak a new vow. The Lantern burns again, and Emberwake inherits a promise it must now keep."
            case "reveal": ending = "You speak the buried names. Nym hears the debt acknowledged at last. The Lantern stays dark; the town must face its history."
            case "break": ending = "The binding breaks. Nym walks free, and the river claims a new course. Emberwake will have to rebuild."
            default: ending = "Nym grants a season of calm. The Lantern flickers, counting down the days until Emberwake’s debt comes due."
            }
            state.recap = ending + (result.result.outcome == .success ? " Your terms hold." : " Your choice holds, but the strain raises the river’s threat. The cost will be remembered.")
        case .recover:
            try state.apply(.init(campaignID: state.id, kind: .worldFactSet, payload: ["key": "lantern-below.recovered", "value": "true"]))
            try state.apply(.init(campaignID: state.id, kind: .worldFactSet, payload: ["key": "reward.brassTideKey", "value": "borrowed-from-sera"]))
            try state.apply(.init(campaignID: state.id, kind: .questUpdated, payload: ["stage": "archive", "objective": "Follow Sera’s safe passage to the flooded archive."]))
            try state.apply(.init(campaignID: state.id, kind: .sceneEntered, payload: ["sceneID": LanternBelowFloodedArchive.sceneID, "locationID": "emberwake.flooded-archive"]))
            // Recovery is an explicit authored interlude, not an unimplemented combat healing rule.
            try state.apply(.init(campaignID: state.id, kind: .combatantHealed, payload: ["combatantID": "player", "healing": String(profile.maximumHitPoints), "source": "authored-shelter-recovery"]))
            state.recap = "Sera tends your wounds through the night. At dawn she lends you a brass tide-key and shows you a dry passage beyond the Shade. Restored, you reach the flooded archive. The river’s warning remains."
        }
        try state.apply(.init(campaignID: state.id, kind: .noteAdded, payload: ["type": "story", "text": state.recap]))
        return state
    }

    public static func addingNote(_ text: String, to original: CampaignState) throws -> CampaignState {
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { throw SoloCampaignError.emptyNote }
        var state = original
        try state.apply(.init(campaignID: state.id, kind: .noteAdded, payload: ["type": "player", "text": note]))
        return state
    }
    private static func audited(_ event: CampaignEvent, seed: UInt64, result: SRD521TestResult) -> CampaignEvent {
        var payload = event.payload
        payload["seed"] = String(seed); payload["modifier"] = String(result.total - result.selectedDie)
        payload["selectedDie"] = String(result.selectedDie)
        return .init(id: event.id, campaignID: event.campaignID, createdAt: event.createdAt, kind: event.kind, payload: payload)
    }

    public static func title(for state: CampaignState) -> String {
        if state.world.encounter?.status == .active { return "Dark Beneath the Bridge" }
        switch state.world.quest.stage { case "archive": return "The Flooded Archive"; case "vault": return "The Lantern Vault"; case "recover": return "The Keeper’s Shelter"; case "complete": return "A Choice Remembered"; default: return "The Lantern Below" }
    }
    public static func hitPoints(in state: CampaignState) -> Int {
        return state.world.encounter?.combatants.first { $0.id == "player" }?.hitPoints ?? 12
    }
    public static func secondWindUses(in state: CampaignState) -> Int { Int(state.world.packState["solo.secondWindUses"] ?? "2") ?? 2 }
}
