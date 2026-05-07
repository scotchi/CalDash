import XCTest
@testable import CalDashKit

private struct StubEvent: FilterableEvent {
    var title: String?
}

final class EventFilterTests: XCTestCase {
    private let events: [StubEvent] = [
        StubEvent(title: "Daily Standup"),
        StubEvent(title: "1:1 with Alice"),
        StubEvent(title: "Lunch"),
        StubEvent(title: "Busy"),
        StubEvent(title: nil),
    ]

    func testEmptyRulesPassThrough() {
        let result = EventFilter.apply(events, rules: [])
        XCTAssertEqual(result.count, events.count)
    }

    func testContainsCaseInsensitive() {
        let rule = FilterRule(pattern: "standup", matchType: .contains, caseSensitive: false)
        let result = EventFilter.apply(events, rules: [rule])
        XCTAssertFalse(result.contains { $0.title == "Daily Standup" })
        XCTAssertEqual(result.count, events.count - 1)
    }

    func testContainsCaseSensitiveDoesNotMatchDifferentCase() {
        let rule = FilterRule(pattern: "standup", matchType: .contains, caseSensitive: true)
        let result = EventFilter.apply(events, rules: [rule])
        XCTAssertEqual(result.count, events.count)
    }

    func testEquals() {
        let rule = FilterRule(pattern: "Busy", matchType: .equals)
        let result = EventFilter.apply(events, rules: [rule])
        XCTAssertFalse(result.contains { $0.title == "Busy" })
        XCTAssertTrue(result.contains { $0.title == "Daily Standup" })
    }

    func testRegex() {
        let rule = FilterRule(pattern: "^1:1", matchType: .regex)
        let result = EventFilter.apply(events, rules: [rule])
        XCTAssertFalse(result.contains { $0.title == "1:1 with Alice" })
    }

    func testDisabledRuleIgnored() {
        let rule = FilterRule(pattern: "Lunch", matchType: .contains, enabled: false)
        let result = EventFilter.apply(events, rules: [rule])
        XCTAssertTrue(result.contains { $0.title == "Lunch" })
    }

    func testEmptyPatternIgnored() {
        let rule = FilterRule(pattern: "", matchType: .contains)
        let result = EventFilter.apply(events, rules: [rule])
        XCTAssertEqual(result.count, events.count)
    }

    func testNilTitleSurvivesUnlessRegexMatchesEmpty() {
        let rule = FilterRule(pattern: "anything", matchType: .contains)
        let result = EventFilter.apply(events, rules: [rule])
        XCTAssertTrue(result.contains { $0.title == nil })
    }

    func testMultipleRulesUnion() {
        let r1 = FilterRule(pattern: "Lunch", matchType: .equals)
        let r2 = FilterRule(pattern: "Busy", matchType: .equals)
        let result = EventFilter.apply(events, rules: [r1, r2])
        XCTAssertFalse(result.contains { $0.title == "Lunch" })
        XCTAssertFalse(result.contains { $0.title == "Busy" })
    }

    func testInvalidRegexDoesNotCrash() {
        let rule = FilterRule(pattern: "[unclosed", matchType: .regex)
        let result = EventFilter.apply(events, rules: [rule])
        XCTAssertEqual(result.count, events.count)
    }
}
