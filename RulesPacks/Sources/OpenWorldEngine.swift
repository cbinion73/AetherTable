import AetherTableCore
import DiceEngine
import Foundation

/// Model proposes fictional circumstances, never dice or resource totals.
public struct WorldActionPlan: Codable, Hashable, Sendable {
    public var kind: String
    public var ability: String
    public var skill: String
    public var difficulty: Int
    public var tool: String
    public var target: String
    public var targetActorID: String?
    public var respondingActorID: String?
    public var spellSource: String?
    public var useSpellSlot: Bool?
    public var ritual: Bool?
    public var weaponTwoHanded: Bool?
    public var targetArmorClass: Int
    public var targetHitPoints: Int
    public var targetCurrentHitPoints: Int = 10
    public var targetSaveModifier: Int
    public var advantage: Bool
    public var disadvantage: Bool
    public var adjacentAlly: Bool
    public var enemyResponds: Bool
    public var enemyAttackBonus: Int
    public var enemyDamageSides: Int
    public var reason: String
    public init(kind: String = "narrative", ability: String = "wisdom", skill: String = "", difficulty: Int = 10, tool: String = "", target: String = "", targetArmorClass: Int = 12, targetHitPoints: Int = 10, targetSaveModifier: Int = 0, advantage: Bool = false, disadvantage: Bool = false, adjacentAlly: Bool = false, enemyResponds: Bool = false, enemyAttackBonus: Int = 2, enemyDamageSides: Int = 6, reason: String = "") {
        self.kind = kind; self.ability = ability; self.skill = skill; self.difficulty = difficulty; self.tool = tool; self.target = target; self.targetArmorClass = targetArmorClass; self.targetHitPoints = targetHitPoints; self.targetSaveModifier = targetSaveModifier; self.advantage = advantage; self.disadvantage = disadvantage; self.adjacentAlly = adjacentAlly; self.enemyResponds = enemyResponds; self.enemyAttackBonus = enemyAttackBonus; self.enemyDamageSides = enemyDamageSides; self.reason = reason
    }
}
public struct WorldResolution: Codable, Hashable, Sendable {
    public var adventure: OpenWorldAdventure
    public var receipt: String
    public var outcome: String
    public var seed: UInt64
}
public enum OpenWorldError: LocalizedError {
    case invalidPlan(String)
    public var errorDescription: String? { switch self { case .invalidPlan(let reason): reason } }
}
public enum OpenWorldEngine {
    public static func resolve(_ plan: WorldActionPlan, in original: OpenWorldAdventure, seed: UInt64) throws -> WorldResolution {
        var state = original
        if let expires = state.guidingBoltExpires, state.turn > expires { state.guidingBoltTarget = nil; state.guidingBoltExpires = nil }
        var serial: UInt64 = 0
        func roll(_ count: Int, _ sides: Int) throws -> [Int] { defer { serial += 1 }; return try DiceEngine.roll(.init(count: count, sides: sides), seed: seed &+ serial).values }
        var receipt: [String] = []
        var outcome = "No roll required"
        let tool = plan.tool.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let ability = SRD521Ability(rawValue: plan.ability.lowercased()) ?? .wisdom
        let skill = plan.skill.lowercased()
        let targetName = plan.target.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitTargetID = plan.targetActorID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let namedTargets = state.opponents.filter { $0.value.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == targetName }
        guard explicitTargetID?.isEmpty == false || namedTargets.count <= 1 else { throw OpenWorldError.invalidPlan("Several people share that name. The GM must identify the intended actor before resolving the turn.") }
        let targetID = explicitTargetID?.isEmpty == false ? explicitTargetID! : namedTargets.first?.key ?? targetName
        guard ["narrative", "check", "weapon", "spell", "secondWind", "rest"].contains(plan.kind) else { throw OpenWorldError.invalidPlan("The GM proposed an unsupported action. Try describing your intent again.") }
        guard (5...25).contains(plan.difficulty), (5...22).contains(plan.targetArmorClass), (1...60).contains(plan.targetHitPoints), (-2...8).contains(plan.targetSaveModifier), (0...8).contains(plan.enemyAttackBonus), [4, 6, 8, 10, 12].contains(plan.enemyDamageSides) else { throw OpenWorldError.invalidPlan("The GM proposed circumstances outside this level-one rules range. Please retry.") }
        guard state.hero.hitPoints > 0 || ["rest", "narrative"].contains(plan.kind) else { throw OpenWorldError.invalidPlan("Your adventurer is down. Describe seeking help or recovering before taking a strenuous action.") }
        func check(modifier: Int, target: Int, attack: Bool, advantage: Bool, disadvantage: Bool) throws -> (Bool, Bool) {
            let mode = SRD521RollMode.effective(hasAdvantage: advantage, hasDisadvantage: disadvantage)
            let dice = try roll(mode == .normal ? 1 : 2, 20)
            let lucky = state.hero.creation?.species == .halfling
            let replacement = lucky && dice.contains(1) ? try roll(1, 20)[0] : nil
            let adjusted = try CreationFeatureRules.d20(dice: dice, mode: mode, halflingLuck: lucky, replacementDie: replacement)
            let die = adjusted.selectedDie
            if adjusted.luckUsed { receipt.append("Halfling Luck: original \(dice), rerolled one natural1 to \(replacement!); resulting dice \(adjusted.dice).") }
            let success = attack && die == 1 ? false : attack && die == 20 ? true : die + modifier >= target
            let critical = attack && die == 20
            outcome = critical ? "Critical hit" : success ? "Success" : "Failure"
            receipt.append("d20 \(dice) \(mode.rawValue), selected \(die) + \(modifier) = \(die + modifier) versus \(target): \(outcome)")
            return (success, critical)
        }
        func establishTarget() throws {
            guard !targetName.isEmpty, ![state.hero.name.lowercased(), "self", "player"].contains(targetName) else { throw OpenWorldError.invalidPlan("An attack needs a distinct target.") }
            if state.opponents[targetID] == nil { state.opponents[targetID] = .init(name: plan.target, armorClass: plan.targetArmorClass, hitPoints: plan.targetHitPoints, maximumHitPoints: plan.targetHitPoints, saveModifier: plan.targetSaveModifier, attackBonus: plan.enemyAttackBonus, damageSides: plan.enemyDamageSides, hostile: true) }
            guard state.opponents[targetID]!.hitPoints > 0 else { throw OpenWorldError.invalidPlan("That target is already defeated.") }
            if plan.kind == "weapon" || ["magic missile", "sacred flame", "fire bolt", "guiding bolt"].contains(tool) { state.opponents[targetID]!.hostile = true }
        }
        func damage(_ count: Int, _ sides: Int, modifier: Int, critical: Bool) throws {
            let dice = try roll(count * (critical ? 2 : 1), sides)
            let amount = max(0, dice.reduce(modifier, +))
            state.opponents[targetID]!.hitPoints = max(0, state.opponents[targetID]!.hitPoints - amount)
            receipt.append("Damage \(dice)d\(sides) + \(modifier) = \(amount). \(plan.target) HP \(state.opponents[targetID]!.hitPoints)/\(state.opponents[targetID]!.maximumHitPoints).")
        }
        switch plan.kind {
        case "narrative": receipt.append("Ordinary action or conversation; no roll or resource expenditure.")
        case "check":
            let trained = state.hero.skills[skill, default: 0]
            let thaumaturge = state.hero.characterClass == .cleric && state.hero.creation?.divineOrder == .thaumaturge && ability == .intelligence && ["arcana", "religion"].contains(skill) ? max(1, state.hero.modifier(.wisdom)) : 0
            _ = try check(modifier: state.hero.modifier(ability) + trained + thaumaturge, target: plan.difficulty, attack: false, advantage: plan.advantage, disadvantage: plan.disadvantage)
            if thaumaturge > 0 { receipt.append("Thaumaturge: added \(thaumaturge) to Intelligence (\(skill)).") }
            receipt.append("\(ability.rawValue) / \(skill.isEmpty ? "untrained" : skill), training +\(trained).")
        case "weapon":
            guard state.hero.weapons.contains(tool) else { throw OpenWorldError.invalidPlan("That weapon is not in your equipped profile.") }
            try establishTarget()
            let ranged = ["shortbow", "longbow"].contains(tool)
            let finesse = ["shortsword", "scimitar", "dagger"].contains(tool)
            let sneakEligible = ranged || finesse
            let modifier = ranged ? state.hero.modifier(.dexterity) : finesse ? max(state.hero.modifier(.dexterity), state.hero.modifier(.strength)) : state.hero.modifier(.strength)
            let guided = state.guidingBoltTarget == targetID
            let archery = CreationFeatureRules.rangedAttackBonus(archery: state.hero.characterClass == .fighter && state.hero.creation?.fightingStyle == .archery, isRanged: ranged)
            if archery > 0 { receipt.append("Archery fighting style: +2 to ranged weapon attack.") }
            let result = try check(modifier: modifier + archery + (state.hero.isProficient(with: tool) ? state.hero.proficiencyBonus : 0), target: state.opponents[targetID]!.armorClass, attack: true, advantage: plan.advantage || guided, disadvantage: plan.disadvantage)
            if guided { state.guidingBoltTarget = nil }
            if result.0 {
                let versatile = ["longsword", "quarterstaff", "spear"].contains(tool)
                let twoHanded = tool == "greatsword" || (versatile && plan.weaponTwoHanded == true)
                let sides = tool == "dagger" ? 4 : tool == "longsword" && twoHanded ? 10 : (["quarterstaff", "spear"].contains(tool) && twoHanded) || ["longsword", "flail", "longbow"].contains(tool) ? 8 : 6
                let count = (tool == "greatsword" ? 2 : 1) * (result.1 ? 2 : 1)
                let first = try roll(count, sides)
                let savage = state.hero.creation?.feats.contains("Savage Attacker") == true
                let second = savage ? try roll(count, sides) : nil
                let greatWeapon = state.hero.characterClass == .fighter && state.hero.creation?.fightingStyle == .greatWeaponFighting && twoHanded
                let weaponDamage = try CreationFeatureRules.weaponDamage(first: first, second: second, sides: sides, modifier: modifier, greatWeaponFighting: greatWeapon, savageAttackerAvailable: savage)
                state.opponents[targetID]!.hitPoints = max(0, state.opponents[targetID]!.hitPoints - weaponDamage.total)
                receipt.append("Weapon damage d\(sides): original \(first)\(second.map { ", Savage Attacker alternate \($0)" } ?? ""), used \(weaponDamage.dice) + \(modifier) = \(weaponDamage.total). \(plan.target) HP \(state.opponents[targetID]!.hitPoints)/\(state.opponents[targetID]!.maximumHitPoints).")
                if greatWeapon { receipt.append("Great Weapon Fighting: weapon damage dice1 or2 count as3 while wielded two-handed.") }
                if savage { receipt.append("Savage Attacker: higher weapon dice set used once this turn; extra Sneak Attack dice excluded.") }
                let mode = SRD521RollMode.effective(hasAdvantage: plan.advantage || guided, hasDisadvantage: plan.disadvantage)
                if state.hero.characterClass == .rogue && sneakEligible && (mode == .advantage || (plan.adjacentAlly && mode != .disadvantage)) {
                    try damage(1, 6, modifier: 0, critical: result.1); receipt.append("Sneak Attack applied once this turn.")
                }
            }
        case "secondWind":
            guard state.hero.characterClass == .fighter, state.hero.secondWindUses > 0 else { throw OpenWorldError.invalidPlan("No Second Wind uses remain.") }
            let die = try roll(1, 10)[0]
            let before = state.hero.hitPoints
            state.hero.hitPoints = min(state.hero.maximumHitPoints, before + die + 1); state.hero.secondWindUses -= 1
            receipt.append("Second Wind d10 \(die) + 1: healed \(state.hero.hitPoints - before) HP, \(state.hero.secondWindUses) uses remain. Bonus action; no weapon attack included in this intent.")
            outcome = "Recovered"
        case "spell":
            let ritual = plan.ritual == true
            if ritual {
                guard CreationSpellCatalog.ritualSpells.contains(tool) else { throw OpenWorldError.invalidPlan("That spell does not have the Ritual tag and cannot bypass its spell slot.") }
                guard !plan.enemyResponds else { throw OpenWorldError.invalidPlan("A ritual requires its normal casting time plus ten uninterrupted minutes of concentration. Resolve the interruption before casting.") }
                guard plan.useSpellSlot != true else { throw OpenWorldError.invalidPlan("Choose normal slot casting or ritual casting, not both.") }
            }
            let classKnown = state.hero.spells.contains(tool)
            let bookKnown = ritual && state.hero.characterClass == .wizard && state.hero.spellbook?.contains(tool) == true && state.hero.equipment.contains(where: { $0.caseInsensitiveCompare("Spellbook") == .orderedSame })
            let initiateKnown = state.hero.magicInitiate.map { $0.cantrips.contains(tool) || $0.spell == tool } ?? false
            guard plan.spellSource == nil || ["", "class", "magicInitiate"].contains(plan.spellSource!) else { throw OpenWorldError.invalidPlan("Unknown spellcasting source.") }
            let useInitiate = plan.spellSource == "magicInitiate" || (!classKnown && !bookKnown && initiateKnown && plan.spellSource != "class")
            guard useInitiate ? initiateKnown : classKnown || bookKnown else { throw OpenWorldError.invalidPlan("That spell is not prepared from the selected source. Wizard Ritual Adept also requires a ritual in your spellbook and the book in your possession.") }
            guard let level = CreationSpellCatalog.level(of: tool) else { throw OpenWorldError.invalidPlan("That spell’s mechanics are not implemented in this beta.") }
            let spellAbility = useInitiate ? state.hero.magicInitiate!.ability : state.hero.characterClass == .wizard ? SRD521Ability.intelligence : .wisdom
            if let item = CreationSpellCatalog.utilities[tool]?.requiredItem {
                guard state.hero.equipment.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) else { throw OpenWorldError.invalidPlan("\(tool.capitalized) requires \(item). Your resources are unchanged.") }
            }
            if ritual {
                if let previous = state.hero.concentratingOn {
                    state.hero.activeUtilitySpells?.removeValue(forKey: previous)
                    state.hero.concentratingOn = nil
                    receipt.append("Concentration on \(previous) ends while concentrating on the ritual’s long casting time.")
                }
                receipt.append("Ritual completed: \(CreationSpellCatalog.ritualCastingTime(for: tool)!). Concentration maintained throughout casting. No spell slot or Magic Initiate free casting spent.")
                if bookKnown && !classKnown && !useInitiate { receipt.append("Wizard Ritual Adept: read the unprepared ritual from the carried spellbook.") }
            } else if level > 0 {
                if useInitiate && state.hero.magicInitiate!.freeUsesRemaining > 0 && plan.useSpellSlot != true {
                    state.hero.magicInitiate!.freeUsesRemaining -= 1
                    receipt.append("Magic Initiate: used the once-per-long-rest free casting; no slot spent.")
                } else {
                    guard state.hero.spellSlots > 0 else { throw OpenWorldError.invalidPlan("No first-level spell slots or available Magic Initiate free casting remain. A long rest restores them.") }
                    state.hero.spellSlots -= 1; receipt.append("Spent one level-one spell slot; \(state.hero.spellSlots) remain.")
                }
            }
            receipt.append("Spellcasting source: \(useInitiate ? "Magic Initiate" : "class"), \(spellAbility.rawValue), spell save DC \(8 + state.hero.proficiencyBonus + state.hero.modifier(spellAbility)). \(ritual ? "Ritual casting; components and effect duration unchanged." : "Normal casting; no ritual discount.")")
            if let definition = CreationSpellCatalog.utilities[tool] {
                if definition.concentration {
                    if let previous = state.hero.concentratingOn { state.hero.activeUtilitySpells?.removeValue(forKey: previous); receipt.append("Concentration on \(previous) ends.") }
                    state.hero.concentratingOn = tool
                }
                if definition.consumesItem, let item = definition.requiredItem {
                    state.hero.equipment.removeAll { $0.caseInsensitiveCompare(item) == .orderedSame }
                    for index in state.memories.indices where state.memories[index].category == "inventory" && state.memories[index].name.caseInsensitiveCompare(item) == .orderedSame { state.memories[index].status = "lost" }
                    receipt.append("Consumed \(item).")
                }
                if state.hero.activeUtilitySpells == nil { state.hero.activeUtilitySpells = [:] }
                state.hero.activeUtilitySpells![tool] = (ritual ? "Cast as a ritual: \(CreationSpellCatalog.ritualCastingTime(for: tool)!). " : "") + definition.limits
                receipt.append("\(tool.capitalized): \(definition.limits) Duration and noncombat circumstances are GM-adjudicated; no extra damage, bonuses or unrelated powers.")
                outcome = "Utility spell takes effect within its recorded limits"
            } else { switch tool {
            case "cure wounds", "healing word":
                let dice = try roll(2, tool == "cure wounds" ? 8 : 4)
                let amount = dice.reduce(state.hero.modifier(spellAbility), +)
                if targetName.isEmpty || ["self", "player", state.hero.name.lowercased()].contains(targetName) {
                    let before = state.hero.hitPoints; state.hero.hitPoints = min(state.hero.maximumHitPoints, before + amount)
                    receipt.append("Healing \(dice) + \(state.hero.modifier(spellAbility)): restored \(state.hero.hitPoints - before) HP after maximum-HP cap.")
                } else {
                    if state.opponents[targetID] == nil {
                        guard (0...plan.targetHitPoints).contains(plan.targetCurrentHitPoints) else { throw OpenWorldError.invalidPlan("Invalid starting health for the wounded person.") }
                        state.opponents[targetID] = .init(name: plan.target, armorClass: plan.targetArmorClass, hitPoints: plan.targetCurrentHitPoints, maximumHitPoints: plan.targetHitPoints, saveModifier: plan.targetSaveModifier, attackBonus: plan.enemyAttackBonus, damageSides: plan.enemyDamageSides)
                    }
                    let before = state.opponents[targetID]!.hitPoints
                    state.opponents[targetID]!.hitPoints = min(state.opponents[targetID]!.maximumHitPoints, before + amount)
                    receipt.append("\(plan.target) healing \(dice) + \(state.hero.modifier(spellAbility)): restored \(state.opponents[targetID]!.hitPoints - before) HP, now \(state.opponents[targetID]!.hitPoints)/\(state.opponents[targetID]!.maximumHitPoints).")
                }
                outcome = "Healed"
            case "magic missile":
                try establishTarget()
                let die = try roll(1, 4)[0]; let amount = 3 * (die + 1)
                state.opponents[targetID]!.hitPoints = max(0, state.opponents[targetID]!.hitPoints - amount)
                receipt.append("Three darts: 3 × (d4 \(die) + 1) = \(amount) force damage, no attack or save. Target HP \(state.opponents[targetID]!.hitPoints).")
                outcome = "Magic missiles hit"
            case "sacred flame":
                try establishTarget()
                let save = try roll(1, 20)[0], dc = 8 + state.hero.proficiencyBonus + state.hero.modifier(spellAbility)
                let saveModifier = state.opponents[targetID]!.saveModifier
                receipt.append("Target Dexterity save d20 \(save) + \(saveModifier) versus DC \(dc).")
                if save + saveModifier < dc { try damage(1, 8, modifier: 0, critical: false); outcome = "Target fails its save" } else { outcome = "Target saves; no damage" }
            case "fire bolt", "guiding bolt":
                try establishTarget()
                let modifier = state.hero.proficiencyBonus + state.hero.modifier(spellAbility)
                let guided = state.guidingBoltTarget == targetID
                let hit = try check(modifier: modifier, target: state.opponents[targetID]!.armorClass, attack: true, advantage: plan.advantage || guided, disadvantage: plan.disadvantage)
                if guided { state.guidingBoltTarget = nil }
                if hit.0 { try damage(tool == "guiding bolt" ? 4 : 1, tool == "guiding bolt" ? 6 : 10, modifier: 0, critical: hit.1); if tool == "guiding bolt" { state.guidingBoltTarget = targetID; state.guidingBoltExpires = state.turn + 1 } }
            default: throw OpenWorldError.invalidPlan("No resolver exists for that spell.")
            } }
        case "rest":
            guard !plan.enemyResponds else { throw OpenWorldError.invalidPlan("A long rest needs a safe place and eight hours without an active fight.") }
            guard ["short rest", "long rest"].contains(tool) else { throw OpenWorldError.invalidPlan("Specify a one-hour short rest or eight-hour long rest.") }
            if tool == "short rest" {
                if state.hitDieSpent != true && state.hero.hitPoints < state.hero.maximumHitPoints {
                    let sides = state.hero.characterClass == .fighter ? 10 : state.hero.characterClass == .wizard ? 6 : 8
                    let die = try roll(1, sides)[0], before = state.hero.hitPoints
                    state.hero.hitPoints = min(state.hero.maximumHitPoints, before + max(0, die + state.hero.modifier(.constitution)))
                    state.hitDieSpent = true; receipt.append("Short rest: spent one Hit Die, d\(sides) \(die) + CON \(state.hero.modifier(.constitution)); restored \(state.hero.hitPoints - before) HP.")
                } else { receipt.append(state.hitDieSpent == true ? "Short rest: no Hit Dice remain to heal." : "Short rest: already at full health; Hit Die preserved.") }
                if state.hero.characterClass == .fighter { state.hero.secondWindUses = min(2, state.hero.secondWindUses + 1); receipt.append("Recovered one Second Wind use, capped at two.") }
                if state.hero.characterClass == .wizard && state.arcaneRecoverySpent != true && state.hero.spellSlots < 2 { state.hero.spellSlots += 1; state.arcaneRecoverySpent = true; receipt.append("Arcane Recovery restores one level-one slot; used until long rest.") }
            } else {
                state.hero.hitPoints = state.hero.maximumHitPoints
                state.hero.spellSlots = [.wizard, .cleric].contains(state.hero.characterClass) ? 2 : 0
                state.hero.secondWindUses = state.hero.characterClass == .fighter ? 2 : 0
                state.hitDieSpent = false; state.arcaneRecoverySpent = false
                state.hero.magicInitiate?.freeUsesRemaining = 1
                state.hero.concentratingOn = nil
                state.hero.activeUtilitySpells = state.hero.activeUtilitySpells?.filter { $0.key == "illusory script" }
                receipt.append("Eight-hour long rest: hit points and class resources restored.")
            }
            state.rests += 1; outcome = "Rest completed"
        default: break
        }
        if plan.enemyResponds && state.hero.hitPoints > 0 {
            let explicitResponder = plan.respondingActorID?.trimmingCharacters(in: .whitespacesAndNewlines)
            let responderID: String
            if let explicitResponder, !explicitResponder.isEmpty {
                if state.opponents[explicitResponder] == nil && explicitResponder == targetID { try establishTarget() }
                responderID = explicitResponder
            } else if state.opponents[targetID]?.hostile == true {
                responderID = targetID
            } else {
                let hostiles = state.opponents.filter { $0.value.hostile && $0.value.hitPoints > 0 }
                if hostiles.count == 1 { responderID = hostiles.first!.key }
                else if hostiles.isEmpty && state.opponents[targetID] == nil && !["cure wounds", "healing word"].contains(tool) {
                    try establishTarget(); responderID = targetID
                } else { throw OpenWorldError.invalidPlan("The GM must identify which hostile is responding. Your turn has not changed.") }
            }
            guard let enemy = state.opponents[responderID], enemy.hostile else { throw OpenWorldError.invalidPlan("The responding actor must be an established hostile, separate from the person receiving healing.") }
            if enemy.hitPoints > 0 {
            let die = try roll(1, 20)[0]
            let hits = die == 20 || (die != 1 && die + enemy.attackBonus >= state.hero.armorClass)
            receipt.append("Hostile response from \(enemy.name) [\(responderID)] d20 \(die) + \(enemy.attackBonus) versus AC \(state.hero.armorClass): \(hits ? "hit" : "miss").")
            if hits {
                let dice = try roll(die == 20 ? 2 : 1, enemy.damageSides); let amount = dice.reduce(0, +)
                state.hero.hitPoints = max(0, state.hero.hitPoints - amount); receipt.append("Incoming damage \(dice) = \(amount). Hero HP \(state.hero.hitPoints).")
                if let concentration = state.hero.concentratingOn {
                    var maintained = false
                    if state.hero.hitPoints > 0 {
                        let originalDie = try roll(1, 20)[0]
                        let lucky = state.hero.creation?.species == .halfling
                        let replacement = lucky && originalDie == 1 ? try roll(1, 20)[0] : nil
                        let adjusted = try CreationFeatureRules.d20(dice: [originalDie], mode: .normal, halflingLuck: lucky, replacementDie: replacement)
                        let concentrationDie = adjusted.selectedDie
                        if adjusted.luckUsed { receipt.append("Halfling Luck: concentration die1 rerolled to \(concentrationDie).") }
                        let proficient = state.hero.creation?.savingThrowProficiencies.contains(.constitution) ?? (state.hero.characterClass == .fighter)
                        let modifier = state.hero.modifier(.constitution) + (proficient ? state.hero.proficiencyBonus : 0)
                        let dc = min(30, max(10, amount / 2))
                        maintained = concentrationDie + modifier >= dc
                        receipt.append("Concentration save d20 \(concentrationDie) + \(modifier) versus DC\(dc): \(maintained ? "maintained" : "lost").")
                    }
                    if !maintained { state.hero.concentratingOn = nil; state.hero.activeUtilitySpells?.removeValue(forKey: concentration); receipt.append("\(concentration.capitalized) ends.") }
                }
            }
            }
        }
        if let expires = original.guidingBoltExpires, original.turn >= expires, tool != "guiding bolt" { state.guidingBoltTarget = nil; state.guidingBoltExpires = nil }
        state.turn += 1
        receipt.append("Seed \(seed). Hero HP \(state.hero.hitPoints)/\(state.hero.maximumHitPoints).")
        return .init(adventure: state, receipt: receipt.joined(separator: "\n"), outcome: outcome, seed: seed)
    }
}
