import WidgetKit
import SwiftUI
import CalDashKit

/// A button style that does not show any pressed-state visual change.
/// Used at the widget level so clicking anywhere dispatches the AppIntent
/// without making every row dim simultaneously.
private struct InvisibleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct UpcomingEventsWidget: Widget {
    let kind: String = "UpcomingEventsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: EventsTimelineProvider()
        ) { entry in
            // ONE Button at the widget level instead of one per row — per-row
            // Button(intent:) added ~25ms per event of build cost (multiplied by
            // ViewThatFits candidates × columns). With a single Button wrapping
            // everything, the AppIntent binding cost is paid once per render
            // regardless of event count.
            Button(intent: OpenCalendarIntent()) {
                EventsEntryView(entry: entry)
            }
            .buttonStyle(InvisibleButtonStyle())
            .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Upcoming Events")
        .description("Shows your upcoming calendar events.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

@main
struct CalDashWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpcomingEventsWidget()
    }
}
