import Foundation
import RulesPacks
import Testing

@Test func editableSuggestionsBuildLegalHeroesForEverySupportedClass() throws {
    for cls in AdventurerClass.allCases {
        let draft = CharacterCreationDraft.suggested(for: cls, name: "Rowan")
        #expect(draft.validationErrors.isEmpty)
        let hero = try draft.build()
        #expect(hero.creation == draft)
        #expect(hero.scores == draft.finalScores)
        #expect(hero.hitPoints == draft.maximumHitPoints)
        #expect(hero.armorClass == draft.armorClass)
        let decoded = try JSONDecoder().decode(OpenWorldHero.self, from: JSONEncoder().encode(hero))
        #expect(decoded == hero)
    }
}

@Test func pointBuyUsesTheNonlinearSRDCostTableAndAll27Points() throws {
    #expect(CharacterCreationDraft.pointCosts == [8: 0, 9: 1, 10: 2, 11: 3, 12: 4, 13: 5, 14: 7, 15: 9])
    var draft = CharacterCreationDraft.suggested(for: .fighter, name: "Dex")
    draft.method = .pointBuy
    draft.baseScores = [.strength: 8, .dexterity: 15, .constitution: 15, .intelligence: 8, .wisdom: 15, .charisma: 8]
    draft.equipmentChoice = .packageB
    #expect(draft.pointBuySpent == 27)
    let hero = try draft.build()
    #expect(hero.scores[.strength] == 10)
    #expect(hero.scores[.constitution] == 16)
    #expect(hero.maximumHitPoints == 13)
    #expect(hero.armorClass == 15)
    draft.baseScores[.strength] = 9
    #expect(throws: CharacterCreationError.self) { try draft.build() }
    draft.baseScores[.strength] = 7
    #expect(throws: CharacterCreationError.self) { try draft.build() }
    draft.baseScores[.strength] = 8; draft.baseScores[.wisdom] = 14
    #expect(draft.pointsRemaining == 2)
    #expect(throws: CharacterCreationError.self) { try draft.build() }
}

@Test func standardArrayRequiresEachScoreExactlyOnce() throws {
    var draft = CharacterCreationDraft.suggested(for: .rogue, name: "R")
    draft.baseScores[.strength] = 15
    #expect(throws: CharacterCreationError.self) { try draft.build() }
    draft.baseScores[.strength] = 12; draft.baseScores.removeValue(forKey: .charisma)
    #expect(throws: CharacterCreationError.self) { try draft.build() }
}

@Test func backgroundBoostsRespectItsThreeAbilitiesAndLegalSplits() throws {
    var draft = CharacterCreationDraft.suggested(for: .wizard, name: "W")
    draft.backgroundBoosts = [.constitution: 1, .intelligence: 1, .wisdom: 1]
    #expect(try draft.build().scores[.intelligence] == 16)
    draft.backgroundBoosts = [.intelligence: 3]
    #expect(throws: CharacterCreationError.self) { try draft.build() }
    draft.backgroundBoosts = [.strength: 2, .intelligence: 1]
    #expect(throws: CharacterCreationError.self) { try draft.build() }
    draft.backgroundBoosts = [.constitution: -1, .intelligence: 2, .wisdom: 2]
    #expect(throws: CharacterCreationError.self) { try draft.build() }
}

@Test func hostileIntegerInputsAreValidationFailuresNotArithmeticTraps() throws {
    var draft = CharacterCreationDraft.suggested(for: .fighter, name: "F")
    draft.baseScores[.strength] = Int.max
    draft.backgroundBoosts[.strength] = Int.max
    #expect(!draft.validationErrors.isEmpty)
    #expect(throws: CharacterCreationError.self) { try draft.build() }
}

@Test func chosenAbilitiesDriveClericSpellDCAndArmorIncludingNegativeDexterity() throws {
    var draft = CharacterCreationDraft.suggested(for: .cleric, name: "C")
    let wise = try draft.build()
    #expect(wise.spellSaveDC == 13)
    #expect(wise.armorClass == 14)
    #expect(wise.maximumHitPoints == 9)
    draft.baseScores[.wisdom] = 8; draft.baseScores[.dexterity] = 15
    let dexterous = try draft.build()
    #expect(dexterous.spellSaveDC == 10)
    #expect(dexterous.spellAttackModifier == 2)
    #expect(dexterous.armorClass == 17)
    #expect(dexterous.spellSlots == 2)
}

@Test func speciesHPAndUnarmoredDefenseAreDerivedCorrectly() throws {
    var draft = CharacterCreationDraft.suggested(for: .fighter, name: "D")
    draft.species = .dwarf
    #expect(try draft.build().maximumHitPoints == 13)
    draft.equipmentChoice = .gold
    #expect(try draft.build().armorClass == 12)
    draft.equipmentChoice = .packageA
    draft.baseScores[.strength] = 8; draft.baseScores[.intelligence] = 15
    #expect(draft.speed == 20)
    #expect(draft.armorClass == 17)
}

@Test func skillsAndExpertiseMustBeDistinctAndActuallyTrained() throws {
    var draft = CharacterCreationDraft.suggested(for: .rogue, name: "R")
    let hero = try draft.build()
    #expect(hero.skills["stealth"] == 4)
    #expect(hero.skills["sleight of hand"] == 4)
    draft.expertise = ["performance", "performance"]
    #expect(throws: CharacterCreationError.self) { try draft.build() }
    draft.expertise = ["stealth", "sleight of hand"]
    draft.classSkills = ["stealth", "stealth", "arcana", "history"]
    #expect(throws: CharacterCreationError.self) { try draft.build() }
}

@Test func wizardSpellbookAndPreparedListRemainSeparateWithoutDroppingSelections() throws {
    var draft = CharacterCreationDraft.suggested(for: .wizard, name: "W")
    let hero = try draft.build()
    #expect(hero.spellbook?.count == 6)
    #expect(hero.spells == draft.cantrips + draft.preparedSpells)
    #expect(!hero.spells.contains("unseen servant"))
    #expect(hero.magicInitiate?.spell == draft.originSpell)
    draft.preparedSpells[0] = "wish"
    #expect(throws: CharacterCreationError.self) { try draft.build() }
    draft.preparedSpells[0] = draft.spellbook[0]; draft.spellbook.removeLast()
    #expect(throws: CharacterCreationError.self) { try draft.build() }
}

@Test func thaumaturgeRequiresFourthCantripAndMagicInitiateUsesItsOwnChoices() throws {
    var draft = CharacterCreationDraft.suggested(for: .cleric, name: "C")
    draft.divineOrder = .thaumaturge
    #expect(throws: CharacterCreationError.self) { try draft.build() }
    draft.cantrips.append("mending")
    draft.originSpellAbility = .charisma
    let hero = try draft.build()
    #expect(hero.magicInitiate?.ability == .charisma)
    #expect(hero.spellcastingAbility == .wisdom)
    draft.originSpellAbility = .strength
    #expect(throws: CharacterCreationError.self) { try draft.build() }
}

@Test func humanFeatDuplicatesAndUnknownSpellSelectionsAreRejected() throws {
    var draft = CharacterCreationDraft.suggested(for: .fighter, name: "F")
    draft.humanFeat = .savageAttacker
    #expect(throws: CharacterCreationError.self) { try draft.build() }
    var wizard = CharacterCreationDraft.suggested(for: .wizard, name: "W")
    wizard.cantrips[0] = "wish"
    #expect(throws: CharacterCreationError.self) { try wizard.build() }
}

@Test func creationContextPreservesAppearanceAlignmentAndSelectedIdentity() throws {
    var draft = CharacterCreationDraft.suggested(for: .rogue, name: "Iris")
    draft.species = .orc; draft.alignment = "Chaotic Good"; draft.appearance = "A copper braid and a blue traveling coat."
    let hero = try draft.build()
    #expect(hero.creation?.contextDescription.contains("copper braid") == true)
    #expect(hero.creation?.contextDescription.contains("Orc") == true)
    #expect(hero.creation?.contextDescription.contains("Chaotic Good") == true)
    draft.appearance = String(repeating: "x", count: 1501)
    #expect(throws: CharacterCreationError.self) { try draft.build() }
}

@Test func everyPublishedEquipmentPackageRetainsItsWeapons() throws {
    for cls in AdventurerClass.allCases {
        var draft = CharacterCreationDraft.suggested(for: cls, name: "Arms")
        let choices: [StartingEquipmentChoice] = cls == .fighter ? [.packageA, .packageB, .gold] : [.packageA, .gold]
        for choice in choices {
            draft.equipmentChoice = choice
            let hero = try draft.build()
            #expect(hero.weapons == draft.startingWeapons)
            #expect(Set(hero.weapons).isSubset(of: OpenWorldHero.supportedWeapons))
            #expect(hero.equipment == draft.startingEquipment)
        }
    }
}

@Test func changingClassPreservesIdentityAndAllocatedAbilityScores() throws {
    var draft = CharacterCreationDraft.suggested(for: .fighter, name: "Keira")
    draft.method = .pointBuy; draft.species = .orc
    draft.alignment = "Chaotic Good"; draft.appearance = "Silver braid, green cloak."
    draft.languages = ["Orc", "Goblin"]
    draft.equipmentChoice = .gold; draft.backgroundEquipmentGold = true
    let baseScores = draft.baseScores, boosts = draft.backgroundBoosts
    draft.changeClass(to: .wizard)
    #expect(draft.name == "Keira" && draft.species == .orc && draft.background == .soldier)
    #expect(draft.method == .pointBuy && draft.baseScores == baseScores && draft.backgroundBoosts == boosts)
    #expect(draft.alignment == "Chaotic Good" && draft.appearance == "Silver braid, green cloak.")
    #expect(draft.languages == ["Orc", "Goblin"] && draft.equipmentChoice == .gold && draft.backgroundEquipmentGold)
    #expect(draft.spellbook.count == 6 && draft.preparedSpells.count == 4)
    #expect(draft.validationErrors.isEmpty)
    _ = try draft.build()
    draft.changeClass(to: .rogue)
    #expect(draft.languages == ["Orc", "Goblin"] && !draft.languages.contains(draft.rogueExtraLanguage))
    #expect(draft.baseScores == baseScores && draft.spellbook.isEmpty)
    _ = try draft.build()
}

@Test func changingClassRetainsSharedLegalSkillsAndSpells() throws {
    var draft = CharacterCreationDraft.suggested(for: .wizard, name: "W")
    draft.species = .dwarf
    draft.classSkills = ["insight", "medicine"]
    draft.preparedSpells = ["detect magic", "magic missile", "alarm", "disguise self"]
    draft.changeClass(to: .cleric)
    #expect(draft.classSkills == ["insight", "medicine"])
    #expect(draft.cantrips.contains("light"))
    #expect(draft.preparedSpells.contains("detect magic"))
    #expect(!draft.preparedSpells.contains("magic missile"))
    #expect(draft.background == .sage)
    _ = try draft.build()
}

@Test func changingBackgroundRetainsCompatibleBoostsAndIndependentChoices() throws {
    var draft = CharacterCreationDraft.suggested(for: .wizard, name: "W")
    draft.backgroundBoosts = [.wisdom: 2, .intelligence: 1]
    draft.method = .pointBuy; draft.species = .halfling
    draft.appearance = "A red scarf."; draft.alignment = "Neutral Good"
    let scores = draft.baseScores, spells = draft.preparedSpells
    draft.changeBackground(to: .acolyte)
    #expect(draft.backgroundBoosts == [.wisdom: 2, .intelligence: 1])
    #expect(draft.baseScores == scores && draft.preparedSpells == spells && draft.method == .pointBuy)
    #expect(draft.species == .halfling && draft.appearance == "A red scarf." && draft.alignment == "Neutral Good")
    #expect(draft.originCantrips.allSatisfy { CharacterCreationDraft.cantrips(for: .cleric).contains($0) })
    _ = try draft.build()
    draft.changeBackground(to: .criminal)
    #expect(draft.backgroundBoosts[.intelligence] == 1)
    #expect(draft.originCantrips.isEmpty && draft.originSpell.isEmpty)
    _ = try draft.build()
}

@Test func changingBackgroundRepairsDuplicateHumanFeatWithoutErasingOtherChoices() throws {
    var draft = CharacterCreationDraft.suggested(for: .fighter, name: "F")
    draft.humanFeat = .alert
    draft.changeBackground(to: .criminal)
    #expect(draft.humanFeat == .skilled)
    #expect(draft.skilledSkills.count == 3)
    #expect(Set(draft.classSkills).isDisjoint(with: Set(draft.background.skills)))
    _ = try draft.build()
}

@Test func everyClassBackgroundSpeciesCombinationNormalizesToALegalDraft() throws {
    for cls in AdventurerClass.allCases {
        for background in CharacterBackground.allCases {
            for species in CharacterSpecies.allCases {
                var draft = CharacterCreationDraft.suggested(for: .fighter, name: "Traveler")
                draft.species = species
                draft.changeBackground(to: background)
                draft.changeClass(to: cls)
                #expect(draft.validationErrors.isEmpty)
                let hero = try draft.build()
                #expect(hero.creation?.background == background && hero.creation?.species == species)
            }
        }
    }
}
