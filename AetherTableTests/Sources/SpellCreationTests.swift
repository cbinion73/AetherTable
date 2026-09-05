import AetherTableCore
import DiceEngine
import Foundation
import RulesPacks
import Testing

@Test func everySelectableSpellHasExplicitMechanics() {
    for cls in [AdventurerClass.wizard, .cleric] {
        for spell in CreationSpellCatalog.cantrips(for: cls) + CreationSpellCatalog.levelOneSpells(for: cls) { #expect(CreationSpellCatalog.level(of: spell) != nil) }
    }
    #expect(CreationSpellCatalog.cantrips(for: .cleric).count >= 4)
    #expect(CreationSpellCatalog.levelOneSpells(for: .wizard).count >= 6)
}

@Test func preparedUtilitiesSpendSlotsWithoutInventingAttacksAndPersistLimits() throws {
    for spell in CreationSpellCatalog.utilities.keys where CreationSpellCatalog.utilities[spell]?.level == 1 {
        var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
        state.hero.spells = [spell]
        if let item = CreationSpellCatalog.utilities[spell]?.requiredItem { state.hero.equipment.append(item) }
        let result = try OpenWorldEngine.resolve(.init(kind: "spell", tool: spell), in: state, seed: 42)
        #expect(result.adventure.hero.spellSlots == 1)
        #expect(result.adventure.opponents.isEmpty)
        #expect(!result.receipt.contains("d20"))
        #expect(result.adventure.hero.activeUtilitySpells?[spell] != nil)
        let roundTrip = try JSONDecoder().decode(OpenWorldAdventure.self, from: JSONEncoder().encode(result.adventure))
        #expect(roundTrip.hero.activeUtilitySpells == result.adventure.hero.activeUtilitySpells)
    }
}

@Test func unpreparedBookSpellsNeedRitualAdeptAndNonritualsCannotBypassSlots() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    state.hero.spellbook = ["detect magic"]
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(.init(kind: "spell", tool: "detect magic"), in: state, seed: 1) }
    state.hero.spells.append("detect magic")
    var ritual = WorldActionPlan(kind: "spell", tool: "detect magic"); ritual.ritual = true
    let result = try OpenWorldEngine.resolve(ritual, in: state, seed: 1)
    #expect(result.adventure.hero.spellSlots == 2)
    ritual.tool = "magic missile"
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(ritual, in: state, seed: 1) }
    #expect(state.hero.spellSlots == 2)
}

@Test func wizardReadsUnpreparedRitualFromBookAndCannotReadLostBook() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    state.hero.spells = []; state.hero.spellSlots = 0; state.hero.spellbook = ["alarm", "disguise self"]
    var ritual = WorldActionPlan(kind: "spell", tool: "alarm"); ritual.ritual = true
    let result = try OpenWorldEngine.resolve(ritual, in: state, seed: 1)
    #expect(result.receipt.contains("11 minutes"))
    #expect(result.receipt.contains("Ritual Adept"))
    #expect(result.adventure.hero.spellSlots == 0)
    #expect(result.adventure.hero.activeUtilitySpells?["alarm"]?.contains("11 minutes") == true)
    state.hero.equipment.removeAll { $0 == "Spellbook" }
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(ritual, in: state, seed: 1) }
    ritual.tool = "disguise self"
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(ritual, in: state, seed: 1) }
}

@Test func preparedClericAndInitiateRitualsDoNotSpendResources() throws {
    var state = OpenWorldAdventure(hero: .preset(.cleric, name: "C"))
    state.hero.spells = ["detect magic"]; state.hero.spellSlots = 0
    var ritual = WorldActionPlan(kind: "spell", tool: "detect magic"); ritual.ritual = true
    let cleric = try OpenWorldEngine.resolve(ritual, in: state, seed: 1)
    #expect(cleric.adventure.hero.concentratingOn == "detect magic")
    #expect(cleric.adventure.hero.spellSlots == 0)
    state.hero.spells = []
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(ritual, in: state, seed: 1) }
    state.hero.magicInitiate = .init(cantrips: ["light", "mending"], spell: "detect magic", ability: .charisma)
    let initiate = try OpenWorldEngine.resolve(ritual, in: state, seed: 1)
    #expect(initiate.adventure.hero.magicInitiate?.freeUsesRemaining == 1)
    #expect(initiate.receipt.contains("charisma"))
}

@Test func ritualRetainsComponentsAndRejectsInterruptionAtomically() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    state.hero.spellbook = ["illusory script"]
    state.hero.concentratingOn = "detect magic"; state.hero.activeUtilitySpells = ["detect magic": "Prior magic"]
    var ritual = WorldActionPlan(kind: "spell", tool: "illusory script"); ritual.ritual = true
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(ritual, in: state, seed: 1) }
    state.hero.equipment.append("Fine ink (10 GP)")
    ritual.enemyResponds = true
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(ritual, in: state, seed: 1) }
    #expect(state.hero.equipment.contains("Fine ink (10 GP)"))
    #expect(state.hero.concentratingOn == "detect magic")
    ritual.enemyResponds = false
    let result = try OpenWorldEngine.resolve(ritual, in: state, seed: 1)
    #expect(result.adventure.hero.spellSlots == 2)
    #expect(!result.adventure.hero.equipment.contains("Fine ink (10 GP)"))
    #expect(result.adventure.hero.concentratingOn == nil)
    #expect(result.adventure.hero.activeUtilitySpells?["detect magic"] == nil)
    let restored = try JSONDecoder().decode(OpenWorldAdventure.self, from: JSONEncoder().encode(result.adventure))
    #expect(restored.hero.activeUtilitySpells?["illusory script"]?.contains("11 minutes") == true)
}

@Test func magicInitiateHasSeparateFreePoolAndSelectedAbility() throws {
    var state = OpenWorldAdventure(hero: .preset(.fighter, name: "F"))
    state.hero.hitPoints = 1
    state.hero.magicInitiate = .init(cantrips: ["sacred flame", "light"], spell: "cure wounds", ability: .charisma)
    let first = try OpenWorldEngine.resolve(.init(kind: "spell", tool: "cure wounds", target: "self"), in: state, seed: 42)
    #expect(first.adventure.hero.magicInitiate?.freeUsesRemaining == 0)
    #expect(first.adventure.hero.spellSlots == 0)
    #expect(first.receipt.contains("charisma"))
    #expect(first.receipt.contains("Healing"))
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(.init(kind: "spell", tool: "cure wounds", target: "self"), in: first.adventure, seed: 42) }
    let rested = try OpenWorldEngine.resolve(.init(kind: "rest", tool: "long rest"), in: first.adventure, seed: 1)
    #expect(rested.adventure.hero.magicInitiate?.freeUsesRemaining == 1)
    #expect(rested.adventure.hero.spellSlots == 0)
}

@Test func initiateCanSpendClassSlotAndConsumableComponentsStayConsumed() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    state.hero.magicInitiate = .init(cantrips: ["light", "mending"], spell: "detect magic", ability: .charisma)
    var plan = WorldActionPlan(kind: "spell", tool: "detect magic"); plan.useSpellSlot = true
    let result = try OpenWorldEngine.resolve(plan, in: state, seed: 1)
    #expect(result.adventure.hero.spellSlots == 1)
    #expect(result.adventure.hero.magicInitiate?.freeUsesRemaining == 1)
    state.hero.spells = ["illusory script"]
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(.init(kind: "spell", tool: "illusory script"), in: state, seed: 1) }
    state.hero.equipment.append("Fine ink (10 GP)")
    state.memories.append(.init(id: "inventory.ink", category: "inventory", name: "Fine ink (10 GP)", detail: "Purchased ink."))
    let ink = try OpenWorldEngine.resolve(.init(kind: "spell", tool: "illusory script"), in: state, seed: 1)
    let restored = try OpenWorldAdventure.from(ink.adventure.storing(in: CampaignState(title: "Test", rulesPackID: "test")))
    #expect(!restored.hero.equipment.contains("Fine ink (10 GP)"))
    #expect(restored.memories.first { $0.id == "inventory.ink" }?.status == "lost")
}

@Test func halflingLuckIsAppliedInEngineAndReplayUsesSameReplacement() throws {
    var state = OpenWorldAdventure(hero: .preset(.rogue, name: "R"))
    var creation = CharacterCreationDraft.suggested(for: .rogue); creation.species = .halfling
    state.hero.creation = creation
    var seed: UInt64 = 0
    while try DiceEngine.roll(.init(count: 1, sides: 20), seed: seed).values[0] != 1 { seed += 1 }
    let plan = WorldActionPlan(kind: "check", ability: "dexterity", skill: "stealth")
    let first = try OpenWorldEngine.resolve(plan, in: state, seed: seed)
    #expect(first.receipt.contains("Halfling Luck"))
    #expect(first == (try OpenWorldEngine.resolve(plan, in: state, seed: seed)))
    creation.species = .human; state.hero.creation = creation
    #expect(!(try OpenWorldEngine.resolve(plan, in: state, seed: seed)).receipt.contains("Halfling Luck"))
}

@Test func archeryAndGreatWeaponStylesActuallyChangeWeaponResolution() throws {
    var state = OpenWorldAdventure(hero: .preset(.fighter, name: "F"))
    var creation = CharacterCreationDraft.suggested(for: .fighter); creation.fightingStyle = .archery
    state.hero.creation = creation; state.hero.weapons.append("longbow")
    let bow = try OpenWorldEngine.resolve(.init(kind: "weapon", tool: "longbow", target: "Bandit", targetArmorClass: 5, targetHitPoints: 60), in: state, seed: 42)
    #expect(bow.receipt.contains("Archery fighting style"))
    #expect(bow.receipt.contains("+ 6"))
    creation.fightingStyle = .greatWeaponFighting; state.hero.creation = creation
    var seed: UInt64 = 0
    while try !((2...19).contains(DiceEngine.roll(.init(count: 1, sides: 20), seed: seed).values[0])) { seed += 1 }
    let sword = try OpenWorldEngine.resolve(.init(kind: "weapon", tool: "greatsword", target: "Bandit", targetArmorClass: 5, targetHitPoints: 60), in: state, seed: seed)
    #expect(sword.receipt.contains("Great Weapon Fighting"))
    #expect(sword.receipt.contains("Savage Attacker"))
    let dealt = 60 - (try #require(sword.adventure.opponents["bandit"]?.hitPoints))
    #expect((9...15).contains(dealt))
}

@Test func thaumaturgeBonusOnlyAppliesToIntelligenceArcanaAndReligion() throws {
    var state = OpenWorldAdventure(hero: .preset(.cleric, name: "C"))
    var creation = CharacterCreationDraft.suggested(for: .cleric); creation.divineOrder = .thaumaturge
    state.hero.creation = creation
    let religion = try OpenWorldEngine.resolve(.init(kind: "check", ability: "intelligence", skill: "religion"), in: state, seed: 42)
    #expect(religion.receipt.contains("Thaumaturge: added 3"))
    #expect(religion.receipt.contains("+ 5"))
    let wisdom = try OpenWorldEngine.resolve(.init(kind: "check", ability: "wisdom", skill: "religion"), in: state, seed: 42)
    #expect(!wisdom.receipt.contains("Thaumaturge:"))
}
