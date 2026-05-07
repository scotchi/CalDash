import SwiftUI
import WidgetKit
import CalDashKit

private let timeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .none
    f.timeStyle = .short
    return f
}()

private let monthDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("MMMd")
    return f
}()

private let dayOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("d")
    return f
}()

private let fullDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("EEEEMMMd")
    return f
}()

private struct LeftFitCountKey: PreferenceKey {
    static var defaultValue: Int = 0
    static func reduce(value: inout Int, nextValue: () -> Int) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

struct EventsEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: EventsEntry
    @State private var leftFitCount: Int = 0

    var body: some View {
        if entry.accessState != .authorized {
            permissionPlaceholder
        } else if entry.events.isEmpty {
            emptyPlaceholder
        } else {
            groupedListView
        }
    }

    private var permissionPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill").font(.title2)
            Text("Open CalDash to grant Calendar access")
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle").font(.title2).foregroundStyle(.secondary)
            Text("No upcoming events").font(.callout).foregroundStyle(.secondary)
        }
    }

    private var groupedListView: some View {
        // Outer GeometryReader so geo.size.height is the full widget interior
        // (NOT pre-padded). `computeFitCount` subtracts contentVerticalPadding
        // once internally to get usable space.
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 0) {
                if family == .systemExtraLarge {
                    twoColumnLayout(height: geo.size.height)
                } else {
                    let est = computeFitCount(from: 0, height: geo.size.height)
                    adaptiveColumn(events: entry.events, estimate: est)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, contentVerticalPadding)
            .padding(.horizontal, contentHorizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func twoColumnLayout(height: CGFloat) -> some View {
        // Both columns get a heuristic-derived fit estimate so ViewThatFits only
        // needs to evaluate a small window of candidates around it (~9 each)
        // instead of the full ladder up to fetchLimit (60). PreferenceKey
        // publishes the chosen left count so the right column starts exactly
        // where the left column ended — no gaps.
        let leftEst = computeFitCount(from: 0, height: height)
        let leftEnd = leftFitCount > 0 ? leftFitCount : leftEst
        let rightSlice = Array(entry.events.dropFirst(leftEnd))
        let rightEst = computeFitCount(from: leftEnd, height: height)

        return HStack(alignment: .top, spacing: 16) {
            adaptiveColumn(events: entry.events, estimate: leftEst, publishCount: true)
            adaptiveColumn(events: rightSlice, estimate: rightEst, publishCount: false)
        }
        .onPreferenceChange(LeftFitCountKey.self) { newValue in
            if newValue != leftFitCount { leftFitCount = newValue }
        }
    }

    /// Walks the events list starting at `startIndex`, accumulating estimated row
    /// heights (with day-header insertion when the day changes), and returns the
    /// largest count whose accumulated height fits within `height` minus padding.
    /// Conservative by design: errs slightly toward fewer events so the right
    /// column never overlaps with what the left column actually rendered.
    private func computeFitCount(from startIndex: Int, height: CGFloat) -> Int {
        let usable = height - contentVerticalPadding * 2
        guard usable > 0, startIndex < entry.events.count else { return 0 }

        let cal = Calendar.current
        let today = cal.startOfDay(for: entry.date)
        var total: CGFloat = 0
        var lastDay: Date? = nil
        var count = 0

        for i in startIndex..<entry.events.count {
            let event = entry.events[i]
            let day = max(today, cal.startOfDay(for: event.startDate))
            var added: CGFloat = 0

            if day != lastDay {
                if lastDay != nil { added += dayHeaderSpacing }
                added += approxHeaderHeight
                added += 1                  // header's .padding(.bottom, 1)
                added += rowSpacing         // gap from header to first row
            } else {
                added += rowSpacing
            }
            added += approxRowHeight(for: event)

            if total + added > usable { return count }
            total += added
            count += 1
            lastDay = day

            // Cap to avoid pathological iteration on absurdly long event lists.
            if count >= 60 { break }
        }
        return count
    }

    private var approxHeaderHeight: CGFloat {
        family == .systemMedium ? 14 : 16
    }

    private func approxRowHeight(for event: EventDisplay) -> CGFloat {
        // Two-line stacked time only when start and end fall on the same day
        // and it's not all-day — matches the rendering branch in trailingText.
        let stacked = !event.isAllDay
            && Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate)
        let lineHeight: CGFloat = family == .systemMedium ? 19 : 22
        let textHeight = lineHeight * (stacked ? 2 : 1)
        return textHeight + rowVerticalPadding * 2
    }

    @ViewBuilder
    private func adaptiveColumn(
        events: [EventDisplay],
        estimate: Int = 0,
        publishCount: Bool = false
    ) -> some View {
        let n = events.count
        // Narrow candidate window around the heuristic estimate when one is
        // provided. Buffer is asymmetric because the heuristic tends to
        // under-count slightly: try several counts above the estimate first,
        // then a few below as a safety net.
        let candidates: [Int] = {
            guard n > 0 else { return [] }
            if estimate > 0 {
                let upper = min(n, estimate + 5)
                let lower = max(1, estimate - 3)
                return Array((lower...upper).reversed())
            }
            return Array((1...n).reversed())
        }()
        // Compute the full day-grouping once for this call (events are already
        // sorted by start date, so a single pass yields contiguous groups).
        // Each candidate then takes a cheap O(d) prefix slice instead of
        // re-running Dictionary(grouping:) per candidate.
        let groups = computeFullGrouping(events)

        ViewThatFits(in: .vertical) {
            ForEach(candidates, id: \.self) { count in
                let sliced = sliceGrouping(groups, count: count)
                if publishCount {
                    renderColumn(precomputed: sliced)
                        .preference(key: LeftFitCountKey.self, value: count)
                } else {
                    renderColumn(precomputed: sliced)
                }
            }
        }
    }

    private func computeFullGrouping(_ events: [EventDisplay]) -> [(day: Date, events: [EventDisplay])] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: entry.date)
        var result: [(day: Date, events: [EventDisplay])] = []
        var currentDay: Date? = nil
        var currentEvents: [EventDisplay] = []
        for event in events {
            let day = max(today, cal.startOfDay(for: event.startDate))
            if currentDay != day {
                if let cd = currentDay { result.append((cd, currentEvents)) }
                currentDay = day
                currentEvents = [event]
            } else {
                currentEvents.append(event)
            }
        }
        if let cd = currentDay { result.append((cd, currentEvents)) }
        return result
    }

    private func sliceGrouping(
        _ groups: [(day: Date, events: [EventDisplay])],
        count: Int
    ) -> [(day: Date, events: [EventDisplay])] {
        var remaining = count
        var out: [(day: Date, events: [EventDisplay])] = []
        for group in groups {
            if remaining == 0 { break }
            if group.events.count <= remaining {
                out.append(group)
                remaining -= group.events.count
            } else {
                out.append((group.day, Array(group.events.prefix(remaining))))
                remaining = 0
            }
        }
        return out
    }

    private func renderColumn(precomputed: [(day: Date, events: [EventDisplay])]) -> some View {
        VStack(alignment: .leading, spacing: dayHeaderSpacing) {
            ForEach(precomputed, id: \.day) { group in
                VStack(alignment: .leading, spacing: rowSpacing) {
                    Text(dayHeader(group.day))
                        .font(headerFont)
                        .fontWeight(Calendar.current.isDateInToday(group.day) ? .heavy : .semibold)
                        .foregroundStyle(Color.secondary)
                        .textCase(.uppercase)
                        .padding(.bottom, 1)
                    ForEach(group.events) { eventRow($0, day: group.day) }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func eventRow(_ event: EventDisplay, day: Date) -> some View {
        let tint = color(event.calendarColorHex)
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "calendar")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: iconSize, height: iconSize)
                .background(Circle().fill(tint))

            Text(event.title)
                .font(titleFont)
                .foregroundStyle(tint)
                .lineLimit(1)

            Spacer(minLength: 4)

            trailingText(for: event, day: day)
                .font(trailingFont)
                .foregroundStyle(tint)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, rowVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tint.opacity(0.14))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: event, isCurrent: isOngoing(event)))
    }

    private func accessibilityLabel(for event: EventDisplay, isCurrent: Bool) -> String {
        var parts: [String] = [event.title]
        if event.isAllDay {
            if isMultiDayAllDay(event) {
                let range = allDayRangeText(event)
                parts.append(String(localized: "all day, \(range)"))
            } else {
                parts.append(String(localized: "all day"))
            }
        } else {
            let start = timeFormatter.string(from: event.startDate)
            let end = timeFormatter.string(from: event.endDate)
            parts.append(String(localized: "from \(start) to \(end)"))
        }
        if isCurrent { parts.append(String(localized: "in progress")) }
        if !event.calendarTitle.isEmpty { parts.append(event.calendarTitle) }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func trailingText(for event: EventDisplay, day: Date) -> some View {
        if event.isAllDay {
            if isMultiDayAllDay(event) {
                Text(allDayRangeText(event)).fontWeight(.regular)
            } else {
                EmptyView()
            }
        } else {
            let cal = Calendar.current
            let sameDay = cal.isDate(event.startDate, inSameDayAs: event.endDate)
            if sameDay {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(timeFormatter.string(from: event.startDate))
                    Text(timeFormatter.string(from: event.endDate))
                }
            } else {
                Text(timeFormatter.string(from: event.startDate))
            }
        }
    }

    private func isOngoing(_ event: EventDisplay) -> Bool {
        if event.isAllDay { return false }
        return event.startDate <= entry.date && entry.date < event.endDate
    }

    private func isMultiDayAllDay(_ event: EventDisplay) -> Bool {
        guard event.isAllDay else { return false }
        // Calendar-day comparison is DST-safe: a single-day all-day event on a
        // fall-back DST boundary has duration 25h but still occupies one calendar day.
        // Treat the second before endDate as belonging to the last visible day:
        //   - canonical exclusive end (start + 1 day): one-second-before is on the
        //     same calendar day as startDate → single-day.
        //   - inclusive end stored equal to startDate: one-second-before is the day
        //     before startDate → still classified single-day after the guard below.
        let cal = Calendar.current
        let oneSecondBefore = cal.date(byAdding: .second, value: -1, to: event.endDate)
            ?? event.endDate
        // Inclusive-end (endDate == startDate) collapses to single-day.
        if oneSecondBefore <= event.startDate { return false }
        return !cal.isDate(oneSecondBefore, inSameDayAs: event.startDate)
    }

    private func lastVisibleDay(of event: EventDisplay) -> Date {
        let cal = Calendar.current
        guard isMultiDayAllDay(event) else {
            return cal.startOfDay(for: event.startDate)
        }
        // Multi-day all-day: endDate is exclusive midnight, so last visible = endDate − 1 day.
        let oneDayBefore = cal.date(byAdding: .day, value: -1, to: event.endDate) ?? event.endDate
        return cal.startOfDay(for: oneDayBefore)
    }

    private func allDayRangeText(_ event: EventDisplay) -> String {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: event.startDate)
        let endDay = lastVisibleDay(of: event)
        if cal.isDate(startDay, inSameDayAs: endDay) {
            return monthDayFormatter.string(from: startDay)
        }
        let startMonth = cal.component(.month, from: startDay)
        let endMonth = cal.component(.month, from: endDay)
        if startMonth == endMonth {
            return "\(monthDayFormatter.string(from: startDay)) – \(dayOnlyFormatter.string(from: endDay))"
        }
        return "\(monthDayFormatter.string(from: startDay)) – \(monthDayFormatter.string(from: endDay))"
    }

    private func dayHeader(_ day: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return String(localized: "Today") }
        if cal.isDateInTomorrow(day) { return String(localized: "Tomorrow") }
        return fullDayFormatter.string(from: day)
    }

    private func color(_ hex: String) -> Color {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let n = UInt32(h, radix: 16) else { return .red }
        let r = Double((n >> 16) & 0xFF) / 255.0
        let g = Double((n >> 8) & 0xFF) / 255.0
        let b = Double(n & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    // MARK: - Sizing

    private var headerFont: Font {
        family == .systemMedium ? .caption.weight(.bold) : .footnote.weight(.bold)
    }

    private var titleFont: Font {
        family == .systemMedium ? .subheadline.weight(.semibold) : .callout.weight(.semibold)
    }

    private var trailingFont: Font {
        family == .systemMedium ? .subheadline.monospacedDigit() : .callout.monospacedDigit()
    }

    private var iconSize: CGFloat {
        family == .systemMedium ? 18 : 20
    }

    private var rowVerticalPadding: CGFloat { family == .systemMedium ? 3 : 4 }
    private var rowSpacing: CGFloat { family == .systemMedium ? 2 : 3 }
    private var contentVerticalPadding: CGFloat { 8 }
    private var contentHorizontalPadding: CGFloat { family == .systemMedium ? 8 : 10 }
    private var dayHeaderSpacing: CGFloat { family == .systemMedium ? 5 : 6 }
}
