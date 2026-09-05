import DiceEngine
import AetherTableCore
import Foundation
import RulesEngine
import RulesPacks
import Persistence
import Testing

@Test func seededRollsAreRepeatable() throws {
    let expression = DiceExpression(count: 2, sides: 20, modifier: 3)
    let first = try DiceEngine.roll(expression, seed: 42)
    let second = try DiceEngine.roll(expression, seed: 42)
    #expect(first == second)
}

@Test func campaignEventsPersistAndRestore() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try FileCampaignStore(directory: directory)
    var campaign = CampaignState(title: "The First Thread", rulesPackID: "d20-fantasy")
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .actionResolved, payload: ["verb": "attempt", "detail": "open the sealed door", "total": "16"]))
    try await store.save(campaign)
    let restored = try await store.load(id: campaign.id)
    #expect(restored?.id == campaign.id)
    #expect(restored?.events.first?.payload == campaign.events.first?.payload)
    #expect(restored?.recap.contains("16") == true)
}

@Test func rulesPacksControlTheCheckShape() {
    let campaign = CampaignState(title: "Test", rulesPackID: "momentum-2d20")
    let pack = BuiltInRulesPacks.all[1]
    let outcome = RulesEngine().resolve(intent: .init(verb: "scan", detail: "the nebula"), in: campaign, using: pack, seed: 42)
    guard case .accepted(let event) = outcome else { Issue.record("Expected accepted action"); return }
    #expect(event.payload["total"] != nil)
}

@Test func starterWorldStateBeginsWithAPlayableCharacter() {
    let hero = CharacterSheet(name: "Arden", archetype: "Wayfinder", definingDetail: "Hears the river speak.", favoredTrait: .wits)
    let world = WorldState(player: hero)
    #expect(world.locationID == "emberwake.square")
    #expect(world.quest.id == "lantern-below")
    #expect(world.player?.traits[.wits] == 2)
    #expect(world.player?.health == 6)
    #expect(world.facts["lantern.status"] == "extinguished")
}

@Test func reducerAppliesStarterCampaignFactsAndCapsResources() throws {
    var campaign = CampaignState(title: "The Lantern Below", rulesPackID: "d20-fantasy")
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .characterCreated, payload: ["name": "Arden", "archetype": "Wayfinder", "definingDetail": "Hears the river.", "favoredTrait": "wits"]))
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .worldFactSet, payload: ["key": "clue.brassShard", "value": "true"]))
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .resourceChanged, payload: ["resource": "health", "delta": "-8"]))
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .relationshipChanged, payload: ["npcID": "npc.sera", "delta": "7"]))
    #expect(campaign.world.player?.health == 0)
    #expect(campaign.world.player?.conditions.contains(.down) == true)
    #expect(campaign.world.facts["clue.brassShard"] == "true")
    #expect(campaign.world.relationships["npc.sera"] == 2)
}

@Test func reducerRejectsAnEventForAnotherCampaign() throws {
    var campaign = CampaignState(title: "One", rulesPackID: "d20-fantasy")
    let foreign = CampaignEvent(campaignID: CampaignID(), kind: .noteAdded, payload: [:])
    #expect(throws: CampaignReducerError.wrongCampaign) { try campaign.apply(foreign) }
}

@Test func lanternBelowFailureStillCreatesAClueAndAdvancesTheStory() throws {
    var campaign = CampaignState(title: "The Lantern Below", rulesPackID: "d20-fantasy")
    try campaign.apply(CampaignEvent(campaignID: campaign.id, kind: .characterCreated, payload: ["name": "Arden", "archetype": "Wayfinder", "favoredTrait": "wits"]))
    for event in LanternBelowSceneOne.enterEvents(for: campaign.id) { try campaign.apply(event) }
    let resolved = CampaignEvent(campaignID: campaign.id, kind: .actionResolved, payload: ["verb": "attempt", "detail": "I study the current.", "total": "4", "band": "miss"])
    try campaign.apply(resolved)
    for event in try LanternBelowSceneOne.consequenceEvents(choiceID: "study", resolved: resolved) { try campaign.apply(event) }
    #expect(campaign.world.facts["clue.archiveCurrent"] == "true")
    #expect(campaign.world.threatClock.current == 1)
    #expect(campaign.world.player?.conditions.contains(.marked) == true)
    #expect(campaign.world.sceneProgress[LanternBelowSceneOne.id] == .completed)
}

@Test func officialSRDReferenceIsSeparateAndCarriesAttribution() {
    let srd = SRD521RulesPack.descriptor
    #expect(!BuiltInRulesPacks.all.map(\.descriptor.id).contains(srd.id))
    #expect(srd.license?.sourceVersion == "5.2.1")
    #expect(srd.license?.licenseName == "Creative Commons Attribution 4.0 International")
    #expect(srd.license?.attribution == SRD521SourceManifest.requiredAttribution)
    #expect(SRD521SourceManifest.pageCount == 364)
    #expect(SRD521SourceManifest.sha256 == "8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87")
}

@Test func onlyExplicitlyLicensedD20SourcesAreBundled() {
    #expect(D20SourceAccessPolicy.bundledRedistributableSources == ["SRD 5.1", "SRD 5.2.1"])
    #expect(SRD51SourceManifest.pageCount == 403)
    #expect(SRD51SourceManifest.sha256 == "2504d2a0abb0a4d491a939be4f17910a2dde0312570ab8d208080225ccf0a1f0")
    #expect(D20SourceAccessPolicy.externalReferenceURL.host == "www.dndbeyond.com")
}

@Test func phoneRuleCatalogSearchesBundledCitedRecordsOffline() throws {
    let catalog = try SRD521RuleCatalog.loadBundled()
    let matches = catalog.search("does a natural twenty hit armor class")
    #expect(matches.first?.rule.id == "srd-5.2.1.playing-the-game.attack-rolls")
    #expect(matches.first?.rule.sourcePage == 7)
    #expect(matches.first?.rule.enforcementStatus == .enforced)
    #expect(catalog.search("", limit: 8).isEmpty)
}

@Test func srdEncounterPersistsCriticalAttackDamageAndTurnOrder() throws {
    var campaign = CampaignState(title: "Test Encounter", rulesPackID: "srd-5.2.1")
    let hero = EncounterCombatant(id: "hero", name: "Arden", team: .player, initiative: 14, maximumHitPoints: 12, armorClass: 15)
    let shade = EncounterCombatant(id: "shade", name: "River Shade", team: .enemy, initiative: 9, maximumHitPoints: 20, armorClass: 12)
    for event in SRD521EncounterEngine.startEvents(campaignID: campaign.id, encounterID: "emberwake.river-shade", title: "Dark Beneath the Bridge", combatants: [hero, shade]) {
        try campaign.apply(event)
    }
    guard let encounter = campaign.world.encounter else { Issue.record("Expected persisted encounter"); return }
    #expect(encounter.activeCombatantID == "hero")
    #expect(encounter.round == 1)

    let resolution = try SRD521EncounterEngine.resolveAttack(
        campaignID: campaign.id,
        in: encounter,
        request: .init(attackerID: "hero", targetID: "shade", ability: .strength, abilityScore: 16, proficiencyBonus: 2, isProficient: true, damage: .init(count: 1, sides: 8, modifier: 3)),
        attackDice: [20],
        damageDice: [4, 6]
    )
    #expect(resolution.attack.outcome == .criticalHit)
    #expect(resolution.damage == 13)
    for event in resolution.events { try campaign.apply(event) }
    #expect(campaign.world.encounter?.combatants.first(where: { $0.id == "shade" })?.hitPoints == 7)

    let next = try SRD521EncounterEngine.nextTurnEvent(campaignID: campaign.id, encounter: campaign.world.encounter!)
    try campaign.apply(next)
    #expect(campaign.world.encounter?.activeCombatantID == "shade")
}

@Test func levelOneSrdCharacterProfilePersistsAndBuildsAWeaponAttack() throws {
    var campaign = CampaignState(title: "Character", rulesPackID: "srd-5.2.1")
    let profile = try SRD521QuickstartCharacter.guardian(name: "Mara")
    try campaign.apply(profile.stateEvent(campaignID: campaign.id))
    let restored = try SRD521CharacterProfile.from(campaign: campaign)
    #expect(restored.name == "Mara")
    #expect(restored.level == 1)
    #expect(restored.proficiencyBonus == 2)
    let attack = try restored.attackRequest(attackID: "longsword", targetID: "shade")
    #expect(attack.abilityScore == 16)
    #expect(attack.damage == .init(count: 1, sides: 8, modifier: 3))
}

@Test func ownedRiverShadeTurnUsesTheSameAuditedSrdEngine() throws {
    var campaign = CampaignState(title: "Enemy Turn", rulesPackID: "srd-5.2.1")
    let hero = EncounterCombatant(id: LanternBelowEncounter.playerID, name: "Arden", team: .player, initiative: 14, maximumHitPoints: 12, armorClass: 16)
    let shade = EncounterCombatant(id: LanternBelowEncounter.riverShadeID, name: "River Shade", team: .enemy, initiative: 9, maximumHitPoints: 20, armorClass: 12)
    for event in SRD521EncounterEngine.startEvents(campaignID: campaign.id, encounterID: "emberwake.river-shade", title: "Dark Beneath the Bridge", combatants: [hero, shade]) { try campaign.apply(event) }
    try campaign.apply(try SRD521EncounterEngine.nextTurnEvent(campaignID: campaign.id, encounter: campaign.world.encounter!))
    let resolution = try SRD521EncounterEngine.resolveAttack(campaignID: campaign.id, in: campaign.world.encounter!, request: LanternBelowEncounter.riverShadeAttack(), attackDice: [20], damageDice: [3, 4])
    #expect(resolution.damage == 9)
    for event in resolution.events { try campaign.apply(event) }
    #expect(campaign.world.encounter?.combatants.first(where: { $0.id == LanternBelowEncounter.playerID })?.hitPoints == 3)
}

@Test func starterEncounterVictoryRewardsClueAndAdvancesTheStory() throws {
    var campaign = CampaignState(title: "Victory", rulesPackID: "srd-5.2.1")
    campaign.world.encounter = .init(id: "emberwake.river-shade", title: "Dark Beneath the Bridge", combatants: [
        .init(id: LanternBelowEncounter.playerID, name: "Arden", team: .player, initiative: 14, maximumHitPoints: 12, armorClass: 16),
        .init(id: LanternBelowEncounter.riverShadeID, name: "River Shade", team: .enemy, initiative: 9, maximumHitPoints: 20, hitPoints: 0, armorClass: 12, conditions: ["defeated"])
    ])
    guard let result = LanternBelowEncounter.completionEvents(campaignID: campaign.id, encounter: campaign.world.encounter!) else { Issue.record("Expected victory completion"); return }
    for event in result.events { try campaign.apply(event) }
    #expect(campaign.world.encounter?.status == .ended)
    #expect(campaign.world.facts["reward.brassTideKey"] == "claimed")
    #expect(campaign.world.quest.stage == "archive")
    #expect(campaign.world.locationID == "emberwake.flooded-archive")
}

@Test func starterEncounterDefeatReturnsToStoryInsteadOfSoftlocking() throws {
    var campaign = CampaignState(title: "Defeat", rulesPackID: "srd-5.2.1")
    campaign.world.encounter = .init(id: "emberwake.river-shade", title: "Dark Beneath the Bridge", combatants: [
        .init(id: LanternBelowEncounter.playerID, name: "Arden", team: .player, initiative: 14, maximumHitPoints: 12, hitPoints: 0, armorClass: 16, conditions: ["defeated"]),
        .init(id: LanternBelowEncounter.riverShadeID, name: "River Shade", team: .enemy, initiative: 9, maximumHitPoints: 20, armorClass: 12)
    ])
    guard let result = LanternBelowEncounter.completionEvents(campaignID: campaign.id, encounter: campaign.world.encounter!) else { Issue.record("Expected defeat completion"); return }
    for event in result.events { try campaign.apply(event) }
    #expect(campaign.world.encounter?.status == .ended)
    #expect(campaign.world.threatClock.current == 1)
    #expect(campaign.world.quest.stage == "recover")
    #expect(campaign.world.locationID == "emberwake.lantern-shelter")
}

@Test func diceStayWithinBounds() throws {
    let roll = try DiceEngine.roll(DiceExpression(count: 3, sides: 6, modifier: 0), seed: 9)
    #expect(roll.values.allSatisfy { (1...6).contains($0) })
}

@Test func srdCoreUsesAbilityAndProficiencyForAnAbilityCheck() throws {
    let request = SRD521TestRequest(
        kind: .abilityCheck,
        ability: .intelligence,
        abilityScore: 15,
        proficiencyBonus: 2,
        isProficient: true,
        target: 15
    )
    let result = try SRD521CoreMechanics.resolve(request: request, dice: [10])
    #expect(result.abilityModifier == 2)
    #expect(result.proficiencyApplied == 2)
    #expect(result.total == 14)
    #expect(result.outcome == .failure)
}

@Test func srdCoreSelectsHighOrLowD20AndCancelsOpposingRollStates() throws {
    let advantage = SRD521TestRequest(kind: .savingThrow, ability: .wisdom, abilityScore: 12, target: 14, rollMode: .advantage)
    let advantaged = try SRD521CoreMechanics.resolve(request: advantage, dice: [4, 16])
    #expect(advantaged.selectedDie == 16)
    #expect(advantaged.outcome == .success)

    let disadvantage = SRD521TestRequest(kind: .savingThrow, ability: .wisdom, abilityScore: 12, target: 14, rollMode: .disadvantage)
    let disadvantaged = try SRD521CoreMechanics.resolve(request: disadvantage, dice: [4, 16])
    #expect(disadvantaged.selectedDie == 4)
    #expect(disadvantaged.outcome == .failure)
    #expect(SRD521RollMode.effective(hasAdvantage: true, hasDisadvantage: true) == .normal)
}

@Test func srdCoreHonorsAttackNaturalTwentyAndOneOnlyForAttacks() throws {
    let attack = SRD521TestRequest(kind: .attackRoll, ability: .strength, abilityScore: 8, target: 99)
    #expect(try SRD521CoreMechanics.resolve(request: attack, dice: [20]).outcome == .criticalHit)
    #expect(try SRD521CoreMechanics.resolve(request: attack, dice: [1]).outcome == .automaticMiss)

    let check = SRD521TestRequest(kind: .abilityCheck, ability: .strength, abilityScore: 20, target: 5)
    #expect(try SRD521CoreMechanics.resolve(request: check, dice: [1]).outcome == .success)
}

@Test func srdCoreUsesOfficialCharacterLevelProficiencyProgression() {
    #expect(SRD521CoreMechanics.proficiencyBonus(forCharacterLevel: 1) == 2)
    #expect(SRD521CoreMechanics.proficiencyBonus(forCharacterLevel: 5) == 3)
    #expect(SRD521CoreMechanics.proficiencyBonus(forCharacterLevel: 9) == 4)
    #expect(SRD521CoreMechanics.proficiencyBonus(forCharacterLevel: 13) == 5)
    #expect(SRD521CoreMechanics.proficiencyBonus(forCharacterLevel: 17) == 6)
    #expect(SRD521CoreMechanics.proficiencyBonus(forCharacterLevel: 21) == nil)
}
