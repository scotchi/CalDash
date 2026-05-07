import Foundation

public protocol FilterableEvent {
    var title: String? { get }
}

public enum EventFilter {
    public static func apply<E: FilterableEvent>(_ events: [E], rules: [FilterRule]) -> [E] {
        let active = rules.filter { $0.enabled && !$0.pattern.isEmpty }
        guard !active.isEmpty else { return events }
        return events.filter { event in
            let title = event.title ?? ""
            return !active.contains { rule in matches(title: title, rule: rule) }
        }
    }

    static func matches(title: String, rule: FilterRule) -> Bool {
        switch rule.matchType {
        case .contains:
            let opts: String.CompareOptions = rule.caseSensitive ? [] : [.caseInsensitive]
            return title.range(of: rule.pattern, options: opts) != nil
        case .equals:
            return rule.caseSensitive
                ? title == rule.pattern
                : title.caseInsensitiveCompare(rule.pattern) == .orderedSame
        case .regex:
            let opts: NSRegularExpression.Options = rule.caseSensitive ? [] : [.caseInsensitive]
            guard let re = try? NSRegularExpression(pattern: rule.pattern, options: opts) else {
                return false
            }
            let range = NSRange(title.startIndex..<title.endIndex, in: title)
            return re.firstMatch(in: title, options: [], range: range) != nil
        }
    }
}
