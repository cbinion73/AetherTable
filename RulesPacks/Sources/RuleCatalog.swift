import Foundation

/// A source-cited rule record designed for offline phone use. The engine uses
/// stable IDs and structured fields; search exists only to help a player or GM
/// locate an explanation.
public struct RuleRecord: Codable, Hashable, Sendable, Identifiable {
    public enum EnforcementStatus: String, Codable, Sendable {
        case enforced
        case referenceOnly
        case planned
    }

    public let id: String
    public let rulesVersion: String
    public let title: String
    public let section: String
    public let sourcePage: Int
    public let keywords: [String]
    public let summary: String
    public let enforcementStatus: EnforcementStatus

    public init(id: String, rulesVersion: String, title: String, section: String, sourcePage: Int, keywords: [String], summary: String, enforcementStatus: EnforcementStatus) {
        self.id = id
        self.rulesVersion = rulesVersion
        self.title = title
        self.section = section
        self.sourcePage = sourcePage
        self.keywords = keywords
        self.summary = summary
        self.enforcementStatus = enforcementStatus
    }
}

public struct RuleSearchResult: Hashable, Sendable {
    public let rule: RuleRecord
    public let score: Int
}

/// Small, deterministic, offline full-text search. A rules pack remains useful
/// with no network, no model download, and no opaque embedding database.
public struct RuleCatalog: Sendable {
    public let records: [RuleRecord]

    public init(records: [RuleRecord]) { self.records = records }

    public func search(_ query: String, limit: Int = 8) -> [RuleSearchResult] {
        guard limit > 0 else { return [] }
        let normalizedQuery = normalized(query)
        let queryTokens = tokens(in: normalizedQuery)
        guard !queryTokens.isEmpty else { return [] }

        return records.compactMap { rule in
            let title = normalized(rule.title)
            let keywords = rule.keywords.map(normalized)
            let section = normalized(rule.section)
            let summary = normalized(rule.summary)
            var score = title.contains(normalizedQuery) ? 50 : 0
            for token in queryTokens {
                if title.contains(token) { score += 15 }
                if keywords.contains(where: { $0.contains(token) }) { score += 10 }
                if section.contains(token) { score += 5 }
                if summary.contains(token) { score += 2 }
            }
            return score > 0 ? RuleSearchResult(rule: rule, score: score) : nil
        }
        .sorted { lhs, rhs in lhs.score == rhs.score ? lhs.rule.id < rhs.rule.id : lhs.score > rhs.score }
        .prefix(limit)
        .map { $0 }
    }

    private func normalized(_ text: String) -> String {
        let numericWords = text.lowercased()
            .replacingOccurrences(of: "twenty", with: "20")
        return numericWords.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
        }.reduce(into: "") { $0.append($1) }
    }

    private func tokens(in text: String) -> [String] {
        Array(Set(text.split(separator: " ").map(String.init).filter { $0.count > 1 })).sorted()
    }
}

public enum RuleCatalogError: Error, Equatable {
    case bundledResourceNotFound(String)
    case unreadableBundledResource(String)
}

public enum SRD521RuleCatalog {
    public static func loadBundled() throws -> RuleCatalog {
        let filename = "Rules.srd-5.2.1"
        guard let url = Bundle(for: RulesPacksBundleAnchor.self).url(forResource: filename, withExtension: "json") else {
            throw RuleCatalogError.bundledResourceNotFound(filename)
        }
        guard let data = try? Data(contentsOf: url), let records = try? JSONDecoder().decode([RuleRecord].self, from: data) else {
            throw RuleCatalogError.unreadableBundledResource(filename)
        }
        return RuleCatalog(records: records)
    }
}

private final class RulesPacksBundleAnchor {}
