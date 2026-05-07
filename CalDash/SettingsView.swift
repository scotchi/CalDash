import SwiftUI
import WidgetKit
import CalDashKit

struct SettingsView: View {
    @EnvironmentObject var ruleStore: FilterRuleStore
    @EnvironmentObject var permissions: PermissionsModel

    var body: some View {
        TabView {
            FilterRulesView()
                .tabItem { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding()
    }
}

@MainActor
private final class WidgetReloadDebouncer: ObservableObject {
    private var task: Task<Void, Never>?

    func schedule(after seconds: Double = 1.5) {
        task?.cancel()
        task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
            self?.task = nil
        }
    }

    func now() {
        task?.cancel()
        task = nil
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct FilterRulesView: View {
    @EnvironmentObject var ruleStore: FilterRuleStore
    @EnvironmentObject var permissions: PermissionsModel
    @State private var selection: UUID?
    @StateObject private var debouncer = WidgetReloadDebouncer()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hide events whose title matches any of these rules.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if permissions.state != .authorized {
                permissionBanner
            }

            Table(ruleStore.rules, selection: $selection) {
                TableColumn("On") { rule in
                    Toggle("", isOn: binding(for: rule, \.enabled, debounced: false))
                        .labelsHidden()
                }
                .width(36)

                TableColumn("Pattern") { rule in
                    HStack(spacing: 4) {
                        TextField("", text: binding(for: rule, \.pattern, debounced: true))
                        if !patternIsValid(rule) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .help("Invalid regular expression")
                        }
                    }
                }

                TableColumn("Match") { rule in
                    Picker("", selection: binding(for: rule, \.matchType, debounced: false)) {
                        ForEach(FilterRule.MatchType.allCases, id: \.self) { t in
                            Text(t.rawValue.capitalized).tag(t)
                        }
                    }
                    .labelsHidden()
                }
                .width(110)

                TableColumn("Aa") { rule in
                    Toggle("", isOn: binding(for: rule, \.caseSensitive, debounced: false))
                        .labelsHidden()
                        .help("Case sensitive")
                }
                .width(36)
            }
            .frame(minHeight: 380)

            HStack {
                Button {
                    ruleStore.add(FilterRule(pattern: ""))
                    debouncer.now()
                } label: { Image(systemName: "plus") }

                Button {
                    if let id = selection {
                        ruleStore.remove(id: id)
                        selection = nil
                        debouncer.now()
                    }
                } label: { Image(systemName: "minus") }
                .disabled(selection == nil)

                Spacer()

                Button("Refresh widgets now") { debouncer.now() }
            }
        }
    }

    private var permissionBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text("Calendar access is required for the widget to show events.")
            Spacer()
            if permissions.state == .notDetermined {
                Button("Grant access") { Task { await permissions.request() } }
            } else {
                Button("Open System Settings") { permissions.openSystemSettings() }
            }
        }
        .padding(8)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
    }

    private func patternIsValid(_ rule: FilterRule) -> Bool {
        guard rule.matchType == .regex, !rule.pattern.isEmpty else { return true }
        return (try? NSRegularExpression(pattern: rule.pattern)) != nil
    }

    private func binding<Value>(
        for rule: FilterRule,
        _ keyPath: WritableKeyPath<FilterRule, Value>,
        debounced: Bool
    ) -> Binding<Value> {
        Binding(
            get: { rule[keyPath: keyPath] },
            set: { newValue in
                var copy = rule
                copy[keyPath: keyPath] = newValue
                ruleStore.update(copy)
                if debounced {
                    debouncer.schedule()
                } else {
                    debouncer.now()
                }
            }
        )
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
            Text("CalDash").font(.title2).bold()
            Text("A configurable upcoming-events widget for macOS.")
                .foregroundStyle(.secondary)
            Button("Refresh widgets now") {
                WidgetCenter.shared.reloadAllTimelines()
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
