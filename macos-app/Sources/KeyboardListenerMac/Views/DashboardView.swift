import Charts
import SwiftUI

struct DashboardView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard Listener")
                        .font(.largeTitle)
                    Text(appState.isListening ? "Capturing keyboard metadata" : "Capture paused")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(appState.isListening ? "Pause" : "Start") {
                    appState.toggleListening()
                }
                .keyboardShortcut(.defaultAction)
            }

            HStack(spacing: 16) {
                StatCard(title: "Today", value: "\(appState.todayCount)", subtitle: "Captured key events")
                StatCard(title: "Pending", value: "\(appState.pendingUploadCount)", subtitle: "Waiting to sync")
                StatCard(
                    title: "Access",
                    value: appState.hasAccessibilityAccess ? "Granted" : "Needed",
                    subtitle: "Accessibility permission"
                )
            }

            GroupBox("Last Hour") {
                if appState.recentBuckets.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("No events yet")
                            .font(.headline)
                        Text("Start listening to populate the recent trend view.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    Chart(appState.recentBuckets) { bucket in
                        BarMark(
                            x: .value("Minute", bucket.minute),
                            y: .value("Count", bucket.count)
                        )
                        .foregroundStyle(.blue.gradient)
                    }
                    .frame(height: 220)
                }
            }

            GroupBox("Sync") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appState.syncStatus)
                    if let error = appState.lastError {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                    Button("Sync Now") {
                        appState.syncNow()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            SettingsView(appState: appState)
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 680)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 18))
    }
}
