import WidgetKit
import EventKit
import CalDashKit

struct EventsEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
    let events: [EventDisplay]
    let accessState: AccessState
}

struct EventsTimelineProvider: AppIntentTimelineProvider {
    private let store = EventStoreClient.shared

    func placeholder(in context: Context) -> EventsEntry {
        EventsEntry(
            date: .now,
            configuration: ConfigurationAppIntent(),
            events: Self.placeholderEvents(),
            accessState: .authorized
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> EventsEntry {
        await makeEntry(for: configuration, family: context.family)
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<EventsEntry> {
        let entry = await makeEntry(for: configuration, family: context.family)
        let next = Date().addingTimeInterval(15 * 60)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func makeEntry(for configuration: ConfigurationAppIntent, family: WidgetFamily) async -> EventsEntry {
        let access = store.accessState
        guard access == .authorized else {
            return EventsEntry(date: .now, configuration: configuration, events: [], accessState: access)
        }

        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 365, to: now) ?? now.addingTimeInterval(60 * 60 * 24 * 365)

        var events = store.fetchUpcoming(from: now, through: end)
        // EventKit returns all-day events that merely touch the requested window.
        // For all-day events, normalize end to the END of the last visible calendar
        // day so events whose source stores endDate as start-of-last-day midnight
        // (e.g., some Google sync paths) aren't dropped while still active. For
        // timed events, raw endDate suffices.
        let cal = Calendar.current
        events = events.filter { event in
            guard event.isAllDay else { return event.endDate > now }
            let lastDayStart: Date
            if event.endDate > event.startDate.addingTimeInterval(86_400 - 60) {
                // Canonical exclusive end → last visible day = endDate − 1 day.
                lastDayStart = cal.startOfDay(
                    for: cal.date(byAdding: .day, value: -1, to: event.endDate) ?? event.endDate
                )
            } else {
                // Inclusive-or-collapsed end → last visible day = startDate's day.
                lastDayStart = cal.startOfDay(for: event.startDate)
            }
            let endOfLastVisibleDay = cal.date(byAdding: .day, value: 1, to: lastDayStart) ?? lastDayStart
            return endOfLastVisibleDay > now
        }
        if configuration.hideAllDay {
            events = events.filter { !$0.isAllDay }
        }
        let ruleStore = FilterRuleStore() // re-read from App Group on every entry build
        let perWidgetRules = parsePerWidgetRules(configuration.hideContaining)
        events = EventFilter.apply(events, rules: ruleStore.rules + perWidgetRules)

        let limit = fetchLimit(family: family)
        let display = store.display(from: events, limit: limit)
        return EventsEntry(date: now, configuration: configuration, events: display, accessState: access)
    }

    private func parsePerWidgetRules(_ raw: String?) -> [FilterRule] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { FilterRule(pattern: $0, matchType: .contains, caseSensitive: false) }
    }

    private func fetchLimit(family: WidgetFamily) -> Int {
        // Generous ceilings; ViewThatFits picks how many actually render.
        switch family {
        case .systemMedium: return 12
        case .systemLarge: return 24
        case .systemExtraLarge: return 60
        default: return 12
        }
    }

    private static func placeholderEvents() -> [EventDisplay] {
        let now = Date()
        return (0..<4).map { i in
            EventDisplay(
                id: "placeholder-\(i)",
                title: "Upcoming event \(i + 1)",
                startDate: now.addingTimeInterval(Double(i + 1) * 3600),
                endDate: now.addingTimeInterval(Double(i + 2) * 3600),
                isAllDay: false,
                calendarTitle: "Calendar",
                calendarColorHex: "#4A90E2",
                url: nil
            )
        }
    }
}
