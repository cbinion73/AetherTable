import RulesPacks
import Testing

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
