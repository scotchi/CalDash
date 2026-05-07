import AppIntents
#if canImport(AppKit)
import AppKit
#endif

/// AppIntent that opens macOS Calendar.app from a widget click. Lives in the
/// widget extension target so the AppIntents metadata extractor finds it at
/// build time (intents living in linked Swift Packages aren't auto-discovered).
/// Runs in the widget extension process (`openAppWhenRun = false`) — it just
/// asks NSWorkspace to launch the app.
///
/// Note: navigating Calendar.app to a specific date or selecting a specific
/// event would require an `apple-events` entitlement and a properly signed
/// build. Left out for now since the dev build is unsigned.
struct OpenCalendarIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Calendar"
    static var description = IntentDescription("Opens the macOS Calendar app.")
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        #if canImport(AppKit)
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Calendar.app"))
        #endif
        return .result()
    }
}
