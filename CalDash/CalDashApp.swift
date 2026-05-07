import SwiftUI
import EventKit
import WidgetKit
import CalDashKit

@main
struct CalDashApp: App {
    @StateObject private var ruleStore = FilterRuleStore()
    @StateObject private var permissions = PermissionsModel()

    var body: some Scene {
        MenuBarExtra("CalDash", systemImage: "calendar.badge.clock") {
            MenuBarContent()
                .environmentObject(ruleStore)
                .environmentObject(permissions)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(ruleStore)
                .environmentObject(permissions)
                .frame(minWidth: 760, idealWidth: 860, minHeight: 560, idealHeight: 640)
        }
    }
}

@MainActor
final class PermissionsModel: ObservableObject {
    @Published var state: AccessState = EventStoreClient.shared.accessState

    init() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.state = EventStoreClient.shared.accessState
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    func request() async {
        state = await EventStoreClient.shared.requestAccess()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject var permissions: PermissionsModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CalDash").font(.headline)
            switch permissions.state {
            case .authorized:
                Label("Calendar access granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .denied:
                Label("Calendar access denied", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Button("Open System Settings") { permissions.openSystemSettings() }
            case .notDetermined:
                Button("Grant Calendar Access") {
                    Task { await permissions.request() }
                }
            }
            Divider()
            Button("Settings…") { openSettings() }
                .keyboardShortcut(",")
            Button("Refresh Widgets") {
                WidgetCenter.shared.reloadAllTimelines()
            }
            Divider()
            Button("Quit CalDash") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 240)
    }
}
