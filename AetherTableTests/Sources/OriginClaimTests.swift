import AIGM
import RulesPacks
import Testing

@Test func originGateSkipsOrdinaryActionsButRecognizesPersonalPastClaims() {
    #expect(!OriginClaimGate.requiresReview("I buy bread and ask about the river."))
    #expect(OriginClaimGate.requiresReview("My father is the captain, so I enter his office."))
    #expect(OriginClaimGate.requiresReview("I was trained by the royal guard."))
}
@Test func originGateAcceptsExactImmutableOriginQuote() throws {
    let world = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"), creationBackstory: "My mother Mira is a baker in Emberwake.")
    try OriginClaimGate.validateAssessment([.init(disposition: .established, sourceID: "origin", quote: "My mother Mira is a baker in Emberwake.")], playerText: "I visit my mother Mira at her bakery.", adventure: world)
}
@Test func originGateRejectsInventedAndEmptyProof() {
    let world = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"), creationBackstory: "A solitary scholar from Emberwake.")
    for quote in ["My father is the king.", "", "   "] {
        #expect(throws: OpenWorldError.self) { try OriginClaimGate.validateAssessment([.init(disposition: .established, sourceID: "origin", quote: quote)], playerText: "My father is the king.", adventure: world) }
    }
}
@Test func absentBackstoryAndPlayerNotesCannotEstablishPastPrivilege() {
    var world = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"))
    world.transcript.append(.init(role: "player", text: "My father is the king."))
    world.transcript.append(.init(role: "note", text: "My father is the king."))
    let note = world.transcript[1]
    #expect(OriginClaimGate.evidenceSources(in: world).isEmpty)
    for source in ["origin", "gm." + note.id.uuidString] {
        #expect(throws: OpenWorldError.self) { try OriginClaimGate.validateAssessment([.init(disposition: .established, sourceID: source, quote: "My father is the king.")], playerText: "My father is the king.", adventure: world) }
    }
}
@Test func originGateAcceptsPriorEarnedGMRecord() throws {
    var world = OpenWorldAdventure(hero: .preset(.fighter, name: "Rowan"))
    let event = AdventureMessage(role: "gm", text: "After the rescue, Captain Lysa pledged to serve as your mentor.")
    world.transcript.append(event)
    try OriginClaimGate.validateAssessment([.init(disposition: .established, sourceID: "gm." + event.id.uuidString, quote: event.text)], playerText: "I ask my mentor Lysa for advice.", adventure: world)
}
@Test func explicitBluffAndQuestionsDoNotRewriteCanonicalOrigin() throws {
    let world = OpenWorldAdventure(hero: .preset(.rogue, name: "Rowan"))
    try OriginClaimGate.validateAssessment([.init(disposition: .explicitBluff)], playerText: "I lie to the guard: my father is the king.", adventure: world)
    try OriginClaimGate.validateAssessment([.init(disposition: .questionOrOrdinaryAction)], playerText: "Do you know who my father was?", adventure: world)
    #expect(world.creationBackstory == nil && OriginClaimGate.evidenceSources(in: world).isEmpty)
    #expect(throws: OpenWorldError.self) { try OriginClaimGate.validateAssessment([.init(disposition: .explicitBluff)], playerText: "My father is the king.", adventure: world) }
}

@Test func supportedChildhoodParaphraseAndPresentInvestigationPreserveProvenance() throws {
    let origin = "I grew up in the magical city of Aurin. My best friend Elian is an illusionist, and we spent our childhood playing harmless illusion tricks."
    let world = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"), creationBackstory: origin)
    try OriginClaimGate.validateAssessment([
        .init(disposition: .established, sourceID: "origin", quote: "My best friend Elian is an illusionist, and we spent our childhood playing harmless illusion tricks."),
        .init(disposition: .questionOrOrdinaryAction)
    ], playerText: "I grew up with Elian, an illusionist. I examine the strange lights for the familiar signs of illusion magic.", adventure: world)
    #expect(world.creationBackstory == origin)
}

@Test func aRealOriginQuoteDoesNotOverrideAnUnsupportedNobleParentAssessment() {
    let world = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"), creationBackstory: "My best friend Elian is an illusionist.")
    #expect(throws: OpenWorldError.self) {
        try OriginClaimGate.validateAssessment([.init(disposition: .unsupported, sourceID: "origin", quote: "My best friend Elian is an illusionist.")], playerText: "My father is the king, so the guards must admit me.", adventure: world)
    }
}

@Test func unrelatedVerbatimProofCannotAuthorizeNewParentOrRoyalTitle() {
    let quote = "My best friend Elian is an illusionist."
    let world = OpenWorldAdventure(hero: .preset(.wizard, name: "Rowan"), creationBackstory: quote)
    #expect(throws: OpenWorldError.self) {
        try OriginClaimGate.validateAssessment([.init(disposition: .established, sourceID: "origin", quote: quote)], playerText: "My father is the king, so the guards must admit me to the treasury.", adventure: world)
    }
}
