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
            attribution: SRD521SourceManifest.requiredAttribution
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

/// Provenance for the verbatim, separately bundled SRD source document.
/// The document is source material; mechanics become player-facing only after
/// their deterministic implementation and conformance tests are complete.
public enum SRD521SourceManifest {
    public static let version = "5.2.1"
    public static let sourceURL = URL(string: "https://media.dndbeyond.com/compendium-images/srd/5.2/SRD_CC_v5.2.1.pdf")!
    public static let pageCount = 364
    public static let sha256 = "8974902d109d6e63672d7c490bde9ccf052410503d9cfa768237154fbc5e3d87"
    public static let bundledFilename = "SRD_CC_v5.2.1.pdf"
    public static let requiredAttribution = "This work includes material from the System Reference Document 5.2.1 (\"SRD 5.2.1\") by Wizards of the Coast LLC, available at https://www.dndbeyond.com/srd. The SRD 5.2.1 is licensed under the Creative Commons Attribution 4.0 International License, available at https://creativecommons.org/licenses/by/4.0/legalcode."
}

/// A separately archived, CC-BY source for the older 5.1 rules generation.
/// It is never combined with SRD 5.2.1 in a campaign: a campaign must name one
/// rules version, and each implementation carries its own attribution.
public enum SRD51SourceManifest {
    public static let version = "5.1"
    public static let sourceURL = URL(string: "https://media.dndbeyond.com/compendium-images/srd/5.1/SRD_CC_v5.1.pdf")!
    public static let pageCount = 403
    public static let sha256 = "2504d2a0abb0a4d491a939be4f17910a2dde0312570ab8d208080225ccf0a1f0"
    public static let bundledFilename = "SRD_CC_v5.1.pdf"
    public static let requiredAttribution = "This work includes material taken from the System Reference Document 5.1 (\"SRD 5.1\") by Wizards of the Coast LLC and available at https://dnd.wizards.com/resources/systems-reference-document. The SRD 5.1 is licensed under the Creative Commons Attribution 4.0 International License available at https://creativecommons.org/licenses/by/4.0/legalcode."
}

/// Rules may enter an AetherTable distribution only if the source has an
/// explicit redistributable license. Free-to-read web pages are not treated as
/// permission to copy their text, tables, art, or data into a rules package.
public enum D20SourceAccessPolicy {
    public static let bundledRedistributableSources = ["SRD 5.1", "SRD 5.2.1"]
    public static let externalReferenceURL = URL(string: "https://www.dndbeyond.com/sources/dnd/br-2024")!
    public static let externalReferenceLabel = "D&D Beyond Basic Rules (external reference; not bundled)"
}
