import AIGM
import AetherTableCore
import Foundation
import RulesPacks

@main struct GMPlaytest {
    static func main() async {
        do { try await run() }
        catch { print("PLAYTEST FAILED: \(error.localizedDescription)"); exit(1) }
    }
    static func run() async throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let fileIndex = arguments.firstIndex(of: "--state")
        let file = fileIndex.flatMap { arguments.indices.contains($0 + 1) ? URL(fileURLWithPath: arguments[$0 + 1]) : nil }
        let originIndex = arguments.firstIndex(of: "--backstory")
        let origin = originIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        let excluded = [fileIndex, fileIndex.map { $0 + 1 }, originIndex, originIndex.map { $0 + 1 }].compactMap { $0 }
        let text = arguments.enumerated().filter { !excluded.contains($0.offset) }.map(\.element).joined(separator: " ")
        var state: OpenWorldAdventure
        if let file, FileManager.default.fileExists(atPath: file.path) { state = try JSONDecoder().decode(OpenWorldAdventure.self, from: Data(contentsOf: file)) }
        else { state = .init(hero: try CharacterCreationDraft.suggested(for: .wizard, name: "Rowan").build(), creationBackstory: origin) }
        let input = text.isEmpty ? "I ignore the river mystery and visit a bakery. I ask the baker whether the backwards river has changed the bread." : text
        let gm = AppleDungeonMaster()
        let plan = try await gm.plan(playerText: input, adventure: state)
        print("PLAN: \(plan.kind) \(plan.tool) — \(plan.reason)")
        let result = try OpenWorldEngine.resolve(plan, in: state, seed: 42)
        let story = try await gm.tell(playerText: input, resolution: result)
        state = try AdventureTurn.finish(playerText: input, resolution: result, story: story)
        print("\n\(story.prose)\n\nLOCATION: \(state.location)\nRECEIPT: \(result.receipt)")
        for memory in story.memories { print("MEMORY: [\(memory.id)] \(memory.name): \(memory.detail)") }
        if let file { try JSONEncoder().encode(state).write(to: file, options: .atomic); print("SAVED: \(file.path)") }
    }
}
