import Foundation
import RulesPacks
import Testing

private func respondingShade() -> WorldOpponent {
    .init(name: "Shade", armorClass: 12, hitPoints: 60, maximumHitPoints: 60, attackBonus: 2, damageSides: 4, hostile: true)
}

@Test func selfHealingAndEnemyResponseUseSeparateActors() throws {
    var state = OpenWorldAdventure(hero: .preset(.cleric, name: "C"))
    state.hero.hitPoints = 1
    state.opponents["actor.shade"] = respondingShade()
    var plan = WorldActionPlan(kind: "spell", tool: "cure wounds", target: "self", enemyResponds: true)
    plan.respondingActorID = "actor.shade"
    let result = try OpenWorldEngine.resolve(plan, in: state, seed: 3)
    #expect(result.adventure.hero.spellSlots == 1)
    #expect(result.adventure.opponents.count == 1)
    #expect(result.receipt.contains("Hostile response from Shade [actor.shade]"))
    #expect(result.adventure.opponents["actor.shade"]?.hitPoints == 60)
}

@Test func healingAnAllyNeverMakesThemTheResponder() throws {
    var state = OpenWorldAdventure(hero: .preset(.cleric, name: "C"))
    state.opponents["actor.shade"] = respondingShade()
    var plan = WorldActionPlan(kind: "spell", tool: "cure wounds", target: "Lysa", targetHitPoints: 12, enemyResponds: true)
    plan.targetActorID = "person.lysa"
    plan.targetCurrentHitPoints = 1
    plan.respondingActorID = "actor.shade"
    let result = try OpenWorldEngine.resolve(plan, in: state, seed: 3)
    #expect(result.adventure.opponents["person.lysa"]?.hostile == false)
    #expect(result.adventure.opponents["person.lysa"]!.hitPoints > 1)
    #expect(result.receipt.contains("Hostile response from Shade"))
    plan.respondingActorID = "person.lysa"
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(plan, in: state, seed: 3) }
}

@Test func ambiguousHostileResponseRequiresAnIdentity() throws {
    var state = OpenWorldAdventure(hero: .preset(.cleric, name: "C"))
    state.opponents["shade.one"] = respondingShade()
    state.opponents["shade.two"] = respondingShade()
    let plan = WorldActionPlan(kind: "spell", tool: "cure wounds", target: "self", enemyResponds: true)
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(plan, in: state, seed: 3) }
}

@Test func aDefeatedResponderDoesNotAttackAfterTheKillingBlow() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    var shade = respondingShade(); shade.hitPoints = 1
    state.opponents["actor.shade"] = shade
    var plan = WorldActionPlan(kind: "spell", tool: "magic missile", target: "Shade", enemyResponds: true)
    plan.targetActorID = "actor.shade"; plan.respondingActorID = "actor.shade"
    let result = try OpenWorldEngine.resolve(plan, in: state, seed: 3)
    #expect(result.adventure.opponents["actor.shade"]?.hitPoints == 0)
    #expect(!result.receipt.contains("Hostile response"))
}

@Test func fullHealthRestPreservesHitDieForLaterWounds() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    state.hero.spellSlots = 0
    let rested = try OpenWorldEngine.resolve(.init(kind: "rest", tool: "short rest"), in: state, seed: 1)
    #expect(rested.adventure.hitDieSpent != true)
    #expect(rested.adventure.hero.spellSlots == 1)
    var wounded = rested.adventure; wounded.hero.hitPoints = 1
    let healed = try OpenWorldEngine.resolve(.init(kind: "rest", tool: "short rest"), in: wounded, seed: 2)
    #expect(healed.adventure.hitDieSpent == true)
    #expect(healed.adventure.hero.hitPoints > 1)
}

@Test func cancelledAdvantageStillAllowsAllySneakAttack() throws {
    let state = OpenWorldAdventure(hero: .preset(.rogue, name: "R"))
    let plan = WorldActionPlan(kind: "weapon", tool: "shortbow", target: "Shade", targetArmorClass: 5, targetHitPoints: 60, advantage: true, disadvantage: true, adjacentAlly: true)
    let results = try (0..<20).map { try OpenWorldEngine.resolve(plan, in: state, seed: UInt64($0)) }
    let hits = results.filter { $0.outcome != "Failure" }
    #expect(!hits.isEmpty)
    #expect(hits.allSatisfy { $0.receipt.contains("Sneak Attack") && $0.receipt.contains("normal") })
}

@Test func repeatedActorNamesRetainDistinctPersistentHealth() throws {
    var state = OpenWorldAdventure(hero: .preset(.wizard, name: "W"))
    state.opponents["goblin.old"] = .init(name: "Goblin", armorClass: 12, hitPoints: 0, maximumHitPoints: 10, hostile: true)
    var plan = WorldActionPlan(kind: "spell", tool: "magic missile", target: "Goblin", targetHitPoints: 60)
    plan.targetActorID = "goblin.new"
    let first = try OpenWorldEngine.resolve(plan, in: state, seed: 3)
    let reloaded = try JSONDecoder().decode(OpenWorldAdventure.self, from: JSONEncoder().encode(first.adventure))
    #expect(reloaded.opponents["goblin.old"]?.hitPoints == 0)
    #expect(reloaded.opponents["goblin.new"]!.hitPoints > 0)
    let second = try OpenWorldEngine.resolve(plan, in: reloaded, seed: 4)
    #expect(second.adventure.opponents["goblin.new"]!.hitPoints < reloaded.opponents["goblin.new"]!.hitPoints)
    plan.targetActorID = nil
    #expect(throws: OpenWorldError.self) { try OpenWorldEngine.resolve(plan, in: reloaded, seed: 4) }
}
