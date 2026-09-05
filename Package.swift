// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "AetherTablePlaytest",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "GMPlaytest", targets: ["GMPlaytest"])],
    targets: [
        .target(name: "AetherTableCore", path: "AetherTableCore/Sources"),
        .target(name: "DiceEngine", dependencies: ["AetherTableCore"], path: "DiceEngine/Sources"),
        .target(name: "RulesEngine", dependencies: ["AetherTableCore", "DiceEngine"], path: "RulesEngine/Sources"),
        .target(name: "RulesPacks", dependencies: ["AetherTableCore", "DiceEngine", "RulesEngine"], path: "RulesPacks", sources: ["Sources"], resources: [.process("Resources")]),
        .target(name: "AIGM", dependencies: ["AetherTableCore", "RulesEngine", "RulesPacks"], path: "AIGM/Sources"),
        .executableTarget(name: "GMPlaytest", dependencies: ["AIGM", "RulesPacks", "AetherTableCore"], path: "Tools/GMPlaytest")
    ]
)
