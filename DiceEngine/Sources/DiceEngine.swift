import AetherTableCore
import Foundation

public struct DiceExpression: Hashable, Sendable {
    public let count: Int
    public let sides: Int
    public let modifier: Int
    public init(count: Int, sides: Int, modifier: Int = 0) {
        self.count = count; self.sides = sides; self.modifier = modifier
    }
}

public struct DiceRoll: Hashable, Sendable { public let expression: DiceExpression; public let values: [Int]; public let total: Int; public let seed: UInt64 }

public enum DiceError: Error, Equatable { case invalidExpression }

public enum DiceEngine {
    public static func roll(_ expression: DiceExpression, seed: UInt64) throws -> DiceRoll {
        guard (1...100).contains(expression.count), (2...1_000).contains(expression.sides) else { throw DiceError.invalidExpression }
        var generator = SplitMix64(seed: seed)
        let values = (0..<expression.count).map { _ in Int(generator.next() % UInt64(expression.sides)) + 1 }
        return DiceRoll(expression: expression, values: values, total: values.reduce(expression.modifier, +), seed: seed)
    }
}

private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
