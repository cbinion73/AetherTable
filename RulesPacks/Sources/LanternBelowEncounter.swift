/// Owned encounter data for AetherTable’s first SRD-backed scene. The River
/// Shade is original AetherTable content; only its resolution mechanics come
/// from the separately attributed SRD pack.
public enum LanternBelowEncounter {
    public static let riverShadeID = "river-shade"
    public static let playerID = "player"

    public static func riverShadeAttack(targetID: String = playerID) -> SRD521AttackRequest {
        .init(
            attackerID: riverShadeID,
            targetID: targetID,
            ability: .dexterity,
            abilityScore: 14,
            proficiencyBonus: 2,
            isProficient: true,
            damage: .init(count: 1, sides: 6, modifier: 2)
        )
    }
}
