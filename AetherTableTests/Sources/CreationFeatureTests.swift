import Foundation
import RulesPacks
import Testing

@Test func expandedClassesAndAncestriesPersistOnlyImplementedState() throws {
    for characterClass in [AdventurerClass.barbarian, .bard, .druid, .monk, .paladin, .ranger, .sorcerer, .warlock] {
        var draft = CharacterCreationDraft.suggested(for: characterClass, name: "Ari")
        for species in [CharacterSpecies.elf, .gnome, .tiefling, .dragonborn] {
            draft.species = species
            let hero = try draft.build()
            #expect(hero.classFeatures != nil)
            #expect(hero.creation?.species == species)
            #expect(try JSONDecoder().decode(OpenWorldHero.self, from: JSONEncoder().encode(hero)) == hero)
        }
    }
}

@Test func expandedFeatureResourcesResolveAndRecoverDeterministically() throws {
    let barbarian = OpenWorldAdventure(hero: .preset(.barbarian, name: "B"))
    let rage = try OpenWorldEngine.resolve(.init(kind: "feature", tool: "rage"), in: barbarian, seed: 1)
    #expect(rage.adventure.hero.classFeatures?.rageUses == 1)
    let restored = try OpenWorldEngine.resolve(.init(kind: "rest", tool: "long rest"), in: rage.adventure, seed: 2)
    #expect(restored.adventure.hero.classFeatures?.rageUses == 2)

    var paladin = OpenWorldAdventure(hero: .preset(.paladin, name: "P")); paladin.hero.hitPoints = 1
    let hands = try OpenWorldEngine.resolve(.init(kind: "feature", tool: "lay on hands"), in: paladin, seed: 1)
    #expect(hands.adventure.hero.hitPoints == 6)
    #expect(hands.adventure.hero.classFeatures?.layOnHandsPool == 0)
}

@Test func levelOneFeaturesApplyConcretePersistedEffects() throws {
    let ranger = OpenWorldAdventure(hero: .preset(.ranger, name: "R"))
    let marked = try OpenWorldEngine.resolve(.init(kind: "feature", tool: "hunter's mark", target: "wolf", targetArmorClass: 10, targetHitPoints: 20), in: ranger, seed: 3)
    #expect(marked.adventure.hero.classFeatures?.markedTarget == "wolf")
    #expect(marked.adventure.hero.classFeatures?.huntersMarkUses == 1)

    let sorcerer = OpenWorldAdventure(hero: .preset(.sorcerer, name: "S"))
    let innate = try OpenWorldEngine.resolve(.init(kind: "feature", tool: "innate sorcery"), in: sorcerer, seed: 4)
    #expect(innate.adventure.hero.classFeatures?.innateSorceryActive == true)
    #expect(innate.adventure.hero.classFeatures?.innateSorceryUses == 1)

    let monk = OpenWorldAdventure(hero: .preset(.monk, name: "M"))
    let strike = try OpenWorldEngine.resolve(.init(kind: "feature", tool: "martial arts", target: "goblin", targetArmorClass: 5, targetHitPoints: 20), in: monk, seed: 5, playerD20: 20)
    #expect(strike.adventure.opponents["goblin"]!.hitPoints < 20)
}

@Test func halflingLuckUsesReplacementEvenWhenItIsAnotherOne() throws {
    let result = try CreationFeatureRules.d20(dice: [1], mode: .normal, halflingLuck: true, replacementDie: 1)
    #expect(result.selectedDie == 1 && result.luckUsed)
    #expect(throws: CreationFeatureError.replacementRequired) { try CreationFeatureRules.d20(dice: [1], mode: .normal, halflingLuck: true) }
    #expect(try CreationFeatureRules.d20(dice: [1], mode: .normal, halflingLuck: false).selectedDie == 1)
}

@Test func halflingLuckReplacesOnlyOneDieBeforeSelectingRollMode() throws {
    let bothOnes = try CreationFeatureRules.d20(dice: [1, 1], mode: .disadvantage, halflingLuck: true, replacementDie: 17)
    #expect(bothOnes.dice == [17, 1] && bothOnes.selectedDie == 1)
    let advantage = try CreationFeatureRules.d20(dice: [1, 8], mode: .advantage, halflingLuck: true, replacementDie: 18)
    #expect(advantage.selectedDie == 18)
}

@Test func fightingStylesRequireTheirEquipmentConditions() throws {
    #expect(CreationFeatureRules.rangedAttackBonus(archery: true, isRanged: true) == 2)
    #expect(CreationFeatureRules.rangedAttackBonus(archery: true, isRanged: false) == 0)
    #expect(CreationFeatureRules.armorClassBonus(defense: true, wearingArmor: false) == 0)
    #expect(CreationFeatureRules.armorClassBonus(defense: true, wearingArmor: true) == 1)
    let ordinary = try CreationFeatureRules.weaponDamage(first: [1, 2], sides: 6, modifier: 3, greatWeaponFighting: false, savageAttackerAvailable: false)
    let styled = try CreationFeatureRules.weaponDamage(first: [1, 2], sides: 6, modifier: 3, greatWeaponFighting: true, savageAttackerAvailable: false)
    #expect(ordinary.total == 6 && styled.total == 9)
}

@Test func savageAttackerChoosesOneCompleteWeaponRollAndCannotBeSpentTwice() throws {
    let result = try CreationFeatureRules.weaponDamage(first: [6, 1], second: [4, 4], sides: 6, modifier: 3, greatWeaponFighting: false, savageAttackerAvailable: true)
    #expect(result.dice == [4, 4] && result.total == 11 && result.savageAttackerUsed)
    #expect(throws: CreationFeatureError.unavailableFeature) { try CreationFeatureRules.weaponDamage(first: [6, 1], second: [4, 4], sides: 6, modifier: 3, greatWeaponFighting: false, savageAttackerAvailable: !result.savageAttackerUsed) }
    let style = try CreationFeatureRules.weaponDamage(first: [6, 1], second: [4, 4], sides: 6, modifier: 3, greatWeaponFighting: true, savageAttackerAvailable: true)
    #expect(style.dice == [6, 3] && style.total == 12)
}

@Test func humanInspirationRefreshesOnceAndConsumesOnlyOneDieReroll() throws {
    var resources = CreationFeatureResources()
    resources.finishLongRest(isHuman: true)
    resources.finishLongRest(isHuman: true)
    let result = try CreationFeatureRules.spendHeroicInspiration(dice: [6, 5], sides: 6, index: 0, replacementDie: 1, resources: resources)
    #expect(result.dice == [1, 5] && !result.resources.heroicInspiration)
    #expect(resources.heroicInspiration)
    #expect(throws: CreationFeatureError.unavailableFeature) { try CreationFeatureRules.spendHeroicInspiration(dice: [1], sides: 6, index: 0, replacementDie: 6, resources: result.resources) }
}

@Test func dwarvenBenefitsApplyOnlyToTheirSpecifiedScope() {
    #expect(CreationFeatureRules.dwarfHitPointBonus(isDwarf: true, level: 1) == 1)
    #expect(CreationFeatureRules.dwarfHitPointBonus(isDwarf: false, level: 1) == 0)
    #expect(CreationFeatureRules.damageAfterDwarvenResistance(9, isDwarf: true, damageType: "Poison") == 4)
    #expect(CreationFeatureRules.damageAfterDwarvenResistance(9, isDwarf: true, damageType: "cold") == 9)
    #expect(CreationFeatureRules.dwarfPoisonSavingThrowAdvantage(isDwarf: true, avoidingOrEndingPoisoned: true))
    #expect(!CreationFeatureRules.dwarfPoisonSavingThrowAdvantage(isDwarf: true, avoidingOrEndingPoisoned: false))
}
