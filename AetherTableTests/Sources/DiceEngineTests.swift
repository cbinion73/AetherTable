import DiceEngine
import Testing

@Test func seededRollsAreRepeatable() throws {
    let expression = DiceExpression(count: 2, sides: 20, modifier: 3)
    let first = try DiceEngine.roll(expression, seed: 42)
    let second = try DiceEngine.roll(expression, seed: 42)
    #expect(first == second)
}

@Test func diceStayWithinBounds() throws {
    let roll = try DiceEngine.roll(DiceExpression(count: 3, sides: 6, modifier: 0), seed: 9)
    #expect(roll.values.allSatisfy { (1...6).contains($0) })
}
