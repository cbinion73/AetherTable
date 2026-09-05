import AIGM
import RulesPacks
import Testing

@Test func discussingAnotherPlaceDoesNotTeleportThePlayer() {
    #expect(WorldIntentGrounding.location(after: "Where is Elara?", current: "Bakery", proposed: "Village square") == "Bakery")
    #expect(WorldIntentGrounding.location(after: "I walk to the village square.", current: "Bakery", proposed: "Village square") == "Village square")
}

@Test func qualityGuardRejectsTheCapturedFestivalCatchphraseAndLeavesStateUntouched() throws {
    var state = OpenWorldAdventure(hero: .preset(.cleric, name: "Liora"))
    state.location = "Festival tavern"
    state.transcript.append(.init(role: "gm", text: "The barkeep frowns. \"The festival's too loud for secrets.\""))
    let resolution = try OpenWorldEngine.resolve(.init(), in: state, seed: 19)
    let echo = WorldStory(prose: "The cartographer looks toward the bottles. \"The festival's too loud for secrets,\" he repeats.", location: "Festival tavern", memories: [])
    #expect(AdventureTurn.repeatsRecentMaterial(echo.prose, transcript: state.transcript))
    #expect(throws: OpenWorldError.self) { try AdventureTurn.finish(playerText: "Why do you keep saying that?", resolution: resolution, story: echo) }
    #expect(resolution.adventure == state)
}

@Test func qualityGuardRequiresAConcreteWhyAnswerButAllowsAGroundedRefusal() {
    #expect(!AdventureTurn.answersPlainQuestion("Why do you keep saying that?", prose: "The barkeep stares into his mug. \"The bottles remember.\""))
    #expect(AdventureTurn.answersPlainQuestion("Why do you keep saying that?", prose: "The barkeep lowers his voice. \"Because the marshal is listening, and she arrested my brother for saying it.\""))
    #expect(AdventureTurn.answersPlainQuestion("I inspect the bottles.", prose: "The nearest bottle holds a curled silver fish scale."))
}

@Test func qualityGuardDetectsRepeatedMaterialOutsideTheOpeningSentence() {
    let prior = AdventureMessage(role: "gm", text: "Warm cinnamon fills the bakery. Iven says, \"Captain Elian bought six loaves before breakfast.\"")
    let candidate = "A pigeon rattles the eaves. Iven laughs. \"Captain Elian bought six loaves before breakfast.\""
    #expect(AdventureTurn.repeatsRecentMaterial(candidate, transcript: [prior]))
}

@Test func explicitSpellUseCannotBeDowngradedToFreeNarration() throws {
    let hero = OpenWorldHero.preset(.wizard, name: "Rowan")
    let plan = WorldIntentGrounding.apply(to: .init(), playerText: "I use Mage Hand to lift the tray.", hero: hero)
    #expect(plan.kind == "spell" && plan.tool == "mage hand")
    let hypothetical = WorldIntentGrounding.apply(to: .init(), playerText: "What happens if I cast Magic Missile?", hero: hero)
    #expect(hypothetical.kind == "narrative")
    let missile = WorldIntentGrounding.apply(to: .init(target: "Shade"), playerText: "I cast Magic Missile at the shade.", hero: hero)
    var empty = OpenWorldAdventure(hero: hero); empty.hero.spellSlots = 0
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(missile, in: empty, seed: 1) }
}

@Test func sceneBoundaryPreservesWorldProseAndOrdinaryNPCDialogue() {
    let scene = "Rain taps the bakery window. Iven rubs flour from his hands.\n\n\"Lysa earned three silver coins yesterday. The purse is still in my cupboard.\""
    #expect(AdventureTurn.worldOnlyPrefix(scene, heroName: "Rowan") == scene)
}

@Test func sceneBoundaryAllowsAcknowledgedTravelButNotANewDeparture() {
    let arrival = "Rowan walks to the orchard. The branches creak in the wind."
    #expect(AdventureTurn.worldOnlyPrefix(arrival, heroName: "Rowan", playerText: "I walk to the orchard.") == arrival)
    #expect(AdventureTurn.worldOnlyPrefix(arrival + " Rowan leaves for the castle.", heroName: "Rowan", playerText: "I walk to the orchard.") == arrival)
}

@Test func sceneBoundaryAlsoProtectsTheHerosFirstName() {
    let world = "The stranger folds her map."
    let prose = world + " Mira replies, \"I will find the lost village.\""
    #expect(AdventureTurn.worldOnlyPrefix(prose, heroName: "Mira Test") == world)
}

@Test func sceneBoundaryDoesNotInventTheHerosPhysicalReaction() {
    let world = "Blue light shimmers above the empty road."
    #expect(AdventureTurn.worldOnlyPrefix(world + " Rowan squints at the lights. He feels uneasy.", heroName: "Rowan") == world)
}

@Test func sceneBoundaryPreservesNPCQuestionsAddressedToPlayer() throws {
    let scene = "Iven holds the brass key against the candlelight.\n\n\"Do you remember the bridge? If you leave before dawn, the ferryman will still be there.\""
    #expect(AdventureTurn.worldOnlyPrefix(scene, heroName: "Rowan") == scene)
    let state = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"))
    let resolution = try OpenWorldEngine.resolve(.init(), in: state, seed: 1)
    let finished = try AdventureTurn.finish(playerText: "I ask Iven where the ferryman went.", resolution: resolution, story: .init(prose: scene, location: "Bakery", memories: []))
    #expect(finished.transcript.last?.text == scene)
}

@Test(arguments: ["Rowan: I will take the road north.", "Rowan decides to follow the ferryman.", "You draw your sword and approach the door."])
func sceneBoundaryStopsBeforeInventedPlayerSpeechOrAction(_ intrusion: String) {
    let scene = "The bell rings across the square. Iven locks the cupboard."
    let output = AdventureTurn.worldOnlyPrefix(scene + "\n\n" + intrusion + " A cart rattles past.", heroName: "Rowan")
    #expect(output == scene)
}

@Test func sceneBoundaryStripsMachineTagsWithoutRemovingNamedNPCs() {
    let tagged = "[place.bakery] Rain taps the window. [person.iven] Iven closes the ledger. [inventory.blue.tin] The blue tin rests on the counter."
    #expect(AdventureTurn.worldOnlyPrefix(tagged, heroName: "Rowan") == "Rain taps the window. Iven closes the ledger. The blue tin rests on the counter.")
}

@Test func finishedStoryReconcilesAcquiredRenamedAndLostInventory() throws {
    let state = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"))
    let initial = try OpenWorldEngine.resolve(.init(), in: state, seed: 1)
    let acquired = try AdventureTurn.finish(playerText: "I accept the tin.", resolution: initial, story: .init(prose: "The blue tin settles into the open satchel.", location: "Bakery", memories: [.init(id: "inventory.tin", category: "inventory", name: "Blue tin", detail: "The adventurer carries the blue tin.")]))
    #expect(acquired.hero.equipment.contains("Blue tin"))
    #expect(!state.hero.equipment.contains("Blue tin"))
    let renamedResolution = try OpenWorldEngine.resolve(.init(), in: acquired, seed: 2)
    let renamed = try AdventureTurn.finish(playerText: "I inspect its lettering.", resolution: renamedResolution, story: .init(prose: "The lettering names the contents: river salt.", location: "Bakery", memories: [.init(id: "inventory.tin", category: "inventory", name: "River salt tin", detail: "The carried blue tin contains river salt.")]))
    #expect(!renamed.hero.equipment.contains("Blue tin"))
    #expect(renamed.hero.equipment.filter { $0 == "River salt tin" }.count == 1)
    let lostResolution = try OpenWorldEngine.resolve(.init(), in: renamed, seed: 3)
    let lost = try AdventureTurn.finish(playerText: "I return the tin.", resolution: lostResolution, story: .init(prose: "The tin rests beside Iven's ledger again.", location: "Bakery", memories: [.init(id: "inventory.tin", category: "inventory", name: "River salt tin", detail: "The tin was returned to Iven.", status: "lost")]))
    #expect(!lost.hero.equipment.contains("River salt tin"))
    #expect(lost.memories.contains { $0.id == "inventory.tin" && $0.status == "lost" })
}

@Test func finishedStoryRemovesLostEquippedWeapon() throws {
    let state = OpenWorldAdventure(hero: .preset(.fighter, name: "Rowan"))
    let sword = try #require(state.memories.first { $0.category == "inventory" && $0.name == "Greatsword" })
    let resolution = try OpenWorldEngine.resolve(.init(), in: state, seed: 1)
    let finished = try AdventureTurn.finish(playerText: "I surrender my greatsword.", resolution: resolution, story: .init(prose: "The guard locks the greatsword in a wooden chest.", location: "Gatehouse", memories: [.init(id: sword.id, category: "inventory", name: sword.name, detail: "The guard confiscated the greatsword.", status: "lost")]))
    #expect(!finished.hero.weapons.contains("greatsword"))
    #expect(!finished.hero.equipment.contains("Greatsword"))
}

@Test(arguments: ["person.iven", "inventory.other.tin"])
func finishedStoryRejectsMachineIdentifiersAsMemoryNames(_ name: String) throws {
    let state = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"))
    let resolution = try OpenWorldEngine.resolve(.init(), in: state, seed: 1)
    #expect(throws: OpenWorldError.self) {
        try AdventureTurn.finish(playerText: "I inspect the tin.", resolution: resolution, story: .init(prose: "The tin bears an old maker's mark.", location: "Bakery", memories: [.init(id: "inventory.tin", category: "inventory", name: name, detail: "An old tin carried by the adventurer.")]))
    }
    #expect(resolution.adventure.hero == state.hero)
}

@Test func finishedStoryRejectsDuplicateInventoryIDsBeforeReconciliation() throws {
    let state = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"))
    let resolution = try OpenWorldEngine.resolve(.init(), in: state, seed: 1)
    #expect(throws: OpenWorldError.self) {
        try AdventureTurn.finish(playerText: "I accept the tin.", resolution: resolution, story: .init(prose: "The blue tin settles into the open satchel.", location: "Bakery", memories: [
            .init(id: "inventory.tin", category: "inventory", name: "Blue tin", detail: "A tin carried by the adventurer."),
            .init(id: "inventory.tin", category: "inventory", name: "Salt tin", detail: "The carried tin contains salt.")
        ]))
    }
}

@Test func retryGuidanceMatchesTheActualFailureInsteadOfAGenericReminder() {
    #expect(AdventureTurn.retryGuidance(for: "The GM repeated recent scene material instead of advancing the conversation.").contains("genuinely new"))
    #expect(AdventureTurn.retryGuidance(for: "The GM repeated a prior scene instead of answering this turn.").contains("genuinely new"))
    #expect(AdventureTurn.retryGuidance(for: "The GM did not answer your plain question. Retrying preserves your intent.").contains("Answer the player's question"))
    #expect(AdventureTurn.retryGuidance(for: "The GM tried to decide your next action. Retry to keep your agency and the same dice result.").contains("Stop the instant"))
    #expect(AdventureTurn.retryGuidance(for: "The GM narrated your character\u{2019}s next action. Retry to keep control of your character.").contains("Stop the instant"))
    #expect(AdventureTurn.retryGuidance(for: "The GM offered suggested actions. Retry to continue freely with the same result.").contains("Do not list options"))
    #expect(AdventureTurn.retryGuidance(for: "The GM did not leave enough of a world-only scene. Retrying preserves your intent.").contains("Write more of the surrounding scene"))
    #expect(AdventureTurn.retryGuidance(for: "Some other unrecognized failure.").contains("Start with an NPC"))
}
