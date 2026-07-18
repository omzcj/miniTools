import Foundation

struct ToolAction: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let isRecommended: Bool
    let searchKeywords: [String]
    let execute: @Sendable () throws -> ClipboardOutput

    init(
        id: String,
        title: String,
        subtitle: String,
        systemImage: String,
        isRecommended: Bool,
        searchKeywords: [String] = [],
        execute: @escaping @Sendable () throws -> ClipboardOutput
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isRecommended = isRecommended
        self.searchKeywords = searchKeywords
        self.execute = execute
    }

    func matches(searchQuery: String) -> Bool {
        searchScore(for: searchQuery) != nil
    }

    func searchScore(for searchQuery: String) -> Int? {
        let normalizedQuery = searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let tokens = normalizedQuery.split(whereSeparator: { $0.isWhitespace }).map(String.init)

        guard !tokens.isEmpty else { return 0 }

        let normalizedTitle = title.lowercased()
        let normalizedSubtitle = subtitle.lowercased()
        let normalizedKeywords = searchKeywords.map { $0.lowercased() }

        var score = 0
        for token in tokens {
            let tokenScore: Int
            if normalizedTitle == token {
                tokenScore = 1_000
            } else if normalizedTitle.hasPrefix(token) {
                tokenScore = 900
            } else if normalizedTitle.contains(token) {
                tokenScore = 800
            } else if normalizedKeywords.contains(token) {
                tokenScore = 700
            } else if normalizedKeywords.contains(where: { $0.hasPrefix(token) }) {
                tokenScore = 650
            } else if normalizedKeywords.contains(where: { $0.contains(token) }) {
                tokenScore = 600
            } else if normalizedSubtitle.contains(token) {
                tokenScore = 400
            } else {
                return nil
            }
            score += tokenScore
        }

        if normalizedTitle == normalizedQuery {
            score += 2_000
        } else if normalizedTitle.hasPrefix(normalizedQuery) {
            score += 1_000
        }
        if isRecommended {
            score += 50
        }
        return score
    }
}

struct ToolActionSection: Identifiable, Sendable {
    let id: String
    let title: String
    var actions: [ToolAction]
}
