import AppIntents
import WidgetKit

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Upcoming Events"
    static var description = IntentDescription("Configure how upcoming events appear.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Hide all-day events", default: false)
    var hideAllDay: Bool

    @Parameter(
        title: "Hide events containing",
        description: "Comma-separated list of substrings. Events whose title contains any of these are hidden. Case-insensitive."
    )
    var hideContaining: String?
}
