import Foundation
import EventKit

extension EventFilter {
    public static func apply(_ events: [EKEvent], rules: [FilterRule]) -> [EKEvent] {
        let active = rules.filter { $0.enabled && !$0.pattern.isEmpty }
        guard !active.isEmpty else { return events }
        return events.filter { event in
            let title = event.title ?? ""
            return !active.contains { matches(title: title, rule: $0) }
        }
    }
}

public struct EventDisplay: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let calendarTitle: String
    public let calendarColorHex: String
    public let url: URL?

    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        calendarTitle: String,
        calendarColorHex: String,
        url: URL?
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarTitle = calendarTitle
        self.calendarColorHex = calendarColorHex
        self.url = url
    }
}

public enum AccessState: Sendable {
    case notDetermined
    case denied
    case authorized
}

public final class EventStoreClient: @unchecked Sendable {
    public static let shared = EventStoreClient()

    private let store = EKEventStore()

    public init() {}

    public var accessState: AccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined: return .notDetermined
        case .fullAccess, .authorized, .writeOnly: return .authorized
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }

    @discardableResult
    public func requestAccess() async -> AccessState {
        do {
            _ = try await store.requestFullAccessToEvents()
        } catch {
            return .denied
        }
        return accessState
    }

    public func fetchUpcoming(
        from start: Date = Date(),
        through end: Date,
        calendars: [EKCalendar]? = nil
    ) -> [EKEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    public func allCalendars() -> [EKCalendar] {
        store.calendars(for: .event)
    }

    public func display(from events: [EKEvent], limit: Int) -> [EventDisplay] {
        events.prefix(limit).map { event in
            let stableID = event.eventIdentifier
                ?? "\(event.calendar?.calendarIdentifier ?? "x")-\(event.startDate.timeIntervalSinceReferenceDate)-\(event.title ?? "")"
            return EventDisplay(
                id: stableID,
                title: event.title ?? String(localized: "(no title)"),
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendar?.title ?? "",
                calendarColorHex: hexString(from: event.calendar?.cgColor),
                url: nil
            )
        }
    }
}

private func hexString(from cgColor: CGColor?) -> String {
    guard let cgColor else { return "#808080" }
    let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    let converted = cgColor.converted(to: srgb, intent: .defaultIntent, options: nil) ?? cgColor
    guard let comps = converted.components else { return "#808080" }
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    switch comps.count {
    case 2: r = comps[0]; g = comps[0]; b = comps[0]
    case 3, 4: r = comps[0]; g = comps[1]; b = comps[2]
    default: return "#808080"
    }
    let ri = Int((max(0, min(1, r)) * 255).rounded())
    let gi = Int((max(0, min(1, g)) * 255).rounded())
    let bi = Int((max(0, min(1, b)) * 255).rounded())
    return String(format: "#%02X%02X%02X", ri, gi, bi)
}
