import AetherTableCore
import Foundation

public struct CampaignLibrary: Sendable {
    public var campaigns: [CampaignState]
    public var unreadableFiles: [String]
    public init(campaigns: [CampaignState] = [], unreadableFiles: [String] = []) { self.campaigns = campaigns; self.unreadableFiles = unreadableFiles }
}
public protocol CampaignStore: Sendable {
    func load(id: CampaignID) async throws -> CampaignState?
    func save(_ campaign: CampaignState) async throws
    func discover() async throws -> CampaignLibrary
}
public extension CampaignStore {
    func discover() async throws -> CampaignLibrary { CampaignLibrary() }
}

public actor InMemoryCampaignStore: CampaignStore {
    private var campaigns: [CampaignID: CampaignState] = [:]
    public init() {}
    public func load(id: CampaignID) async throws -> CampaignState? { campaigns[id] }
    public func save(_ campaign: CampaignState) async throws { campaigns[campaign.id] = campaign }
    public func discover() async throws -> CampaignLibrary { CampaignLibrary(campaigns: Array(campaigns.values)) }
}

/// The initial durable store. It is intentionally simple, human-inspectable JSON;
/// the `CampaignStore` protocol leaves room for SwiftData migration later.
public actor FileCampaignStore: CampaignStore {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileManager: FileManager = .default) throws {
        let root = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        try self.init(directory: root.appendingPathComponent("AetherTable/Campaigns", isDirectory: true), fileManager: fileManager)
    }

    public init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load(id: CampaignID) async throws -> CampaignState? {
        let url = fileURL(for: id)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try decoder.decode(CampaignState.self, from: Data(contentsOf: url))
    }

    public func save(_ campaign: CampaignState) async throws {
        let data = try encoder.encode(campaign)
        try data.write(to: fileURL(for: campaign.id), options: .atomic)
    }

    public func discover() async throws -> CampaignLibrary {
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var result = CampaignLibrary()
        for file in files.filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                let campaign = try decoder.decode(CampaignState.self, from: Data(contentsOf: file))
                guard file.lastPathComponent == "\(campaign.id.rawValue.uuidString).json" else { result.unreadableFiles.append(file.lastPathComponent); continue }
                result.campaigns.append(campaign)
            } catch { result.unreadableFiles.append(file.lastPathComponent) }
        }
        result.campaigns.sort { ($0.events.last?.createdAt ?? .distantPast) > ($1.events.last?.createdAt ?? .distantPast) }
        return result
    }

    private func fileURL(for id: CampaignID) -> URL { directory.appendingPathComponent("\(id.rawValue.uuidString).json") }
}
