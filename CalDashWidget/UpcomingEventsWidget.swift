import WidgetKit
import SwiftUI

struct UpcomingEventsWidget: Widget {
    let kind: String = "UpcomingEventsWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: EventsTimelineProvider()
        ) { entry in
            EventsEntryView(entry: entry)
                .widgetURL(URL(string: "ical://"))
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
