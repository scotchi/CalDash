import Foundation
import Combine

public final class FilterRuleStore: ObservableObject {
    public static let appGroupID = "group.net.scotchi.CalDash"
    private static let key = "filterRules.v1"

    @Published public private(set) var rules: [FilterRule]

    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = nil) {
        let resolved = defaults ?? UserDefaults(suiteName: Self.appGroupID) ?? .standard
        self.defaults = resolved
        self.rules = Self.load(from: resolved)
    }

    public func add(_ rule: FilterRule) {
        rules.append(rule)
        persist()
    }

    public func update(_ rule: FilterRule) {
        guard let i = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[i] = rule
        persist()
    }

    public func remove(id: UUID) {
        rules.removeAll { $0.id == id }
        persist()
    }

    public func replaceAll(_ newRules: [FilterRule]) {
        rules = newRules
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        defaults.set(data, forKey: Self.key)
        // Force flush to disk so a near-immediate widget reload in a different
        // process reads the new value, not a cached older one. `synchronize()`
        // is deprecated for the read-side cache invalidation but still flushes
        // pending writes on the originating process.
        defaults.synchronize()
    }

    private static func load(from defaults: UserDefaults) -> [FilterRule] {
        guard
            let data = defaults.data(forKey: key),
            let rules = try? JSONDecoder().decode([FilterRule].self, from: data)
        else { return [] }
        return rules
    }
}
