import AetherTableCore
import Foundation

/// Separate provenance-bearing package for the official SRD 5.2.1 rules.
/// This declaration is intentionally reference-only until its complete mechanics
/// adapter and conformance tests exist. It is never silently substituted for an
/// original pack and it is not yet available in the playable-pack registry.
public enum SRD521RulesPack {
    public static let descriptor = RulesPackDescriptor(
        id: "srd-5.2.1",
        version: "5.2.1",
        displayName: "SRD 5.2.1 Reference Pack",
        mechanicFamily: "d20",
        standardCheck: .init(count: 1, sides: 20),
        actionVerbs: ["ability check", "attack", "cast", "save"],
        license: .init(
            sourceName: "System Reference Document",
            sourceVersion: "5.2.1",
            licenseName: "Creative Commons Attribution 4.0 International",
            sourceURL: URL(string: "https://www.dndbeyond.com/srd")!,
            attribution: "This work includes material taken from the System Reference Document 5.2.1 by Wizards of the Coast LLC and available at https://www.dndbeyond.com/srd. The System Reference Document 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode."
        )
    )

    /// Content cannot be exposed to players until these independently testable
    /// mechanics have corresponding deterministic adapters.
    public static let requiredMechanics = [
        "ability checks and proficiency",
        "advantage and disadvantage",
        "saving throws",
        "attack rolls, armor class, damage, and conditions",
        "character options and resource rules"
    ]
}
