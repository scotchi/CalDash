import Foundation

public struct FilterRule: Codable, Identifiable, Hashable, Sendable {
    public enum MatchType: String, Codable, CaseIterable, Sendable {
        case contains
        case equals
        case regex
    }

    public var id: UUID
    public var pattern: String
    public var matchType: MatchType
    public var caseSensitive: Bool
    public var enabled: Bool

    public init(
        id: UUID = UUID(),
        pattern: String,
        matchType: MatchType = .contains,
        caseSensitive: Bool = false,
        enabled: Bool = true
    ) {
        self.id = id
        self.pattern = pattern
        self.matchType = matchType
        self.caseSensitive = caseSensitive
        self.enabled = enabled
    }
}
