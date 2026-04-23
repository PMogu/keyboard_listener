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
                StatCard(title: "Range Total", value: "\(appState.remoteStatsTotal)", subtitle: appState.selectedRange.chartTitle)
                StatCard(
                    title: "Access",
                    value: appState.hasAccessibilityAccess ? "Granted" : "Needed",
                    subtitle: "Accessibility permission"
                )
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Range", selection: Binding(
                        get: { appState.selectedRange },
                        set: { appState.selectRange($0) }
                    )) {
                        ForEach(DashboardRange.allCases) { range in
                            Text(range.title).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(appState.remoteStatsStatus)
                        .foregroundStyle(.secondary)

                    if appState.remoteBuckets.isEmpty {
                        EmptyChartState(
                            title: "No synced events",
                            subtitle: "Sync your local data to see the \(appState.selectedRange.chartTitle) trend."
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    } else {
                        Chart(appState.remoteBuckets) { bucket in
                            BarMark(
                                x: .value(xAxisTitle, bucket.bucketStart),
                                y: .value("Count", bucket.count)
                            )
                            .foregroundStyle(.blue.gradient)
                        }
                        .frame(height: 240)
                    }
                }
            } label: {
                Text(appState.selectedRange.chartTitle)
            }

            GroupBox("Top Keys") {
                if appState.topKeyStats.isEmpty {
                    EmptyChartState(
                        title: "No key distribution yet",
                        subtitle: "Top keys will appear here after synced events accumulate."
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    Chart(appState.topKeyStats) { item in
                        BarMark(
                            x: .value("Key", keyLabel(for: item.keyCode)),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(.green.gradient)
                    }
                    .frame(height: 240)
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
        .frame(minWidth: 820, minHeight: 780)
    }

    private var xAxisTitle: String {
        switch appState.selectedRange {
        case .day:
            return "Hour"
        case .week, .month:
            return "Day"
        }
    }

    private func keyLabel(for keyCode: Int) -> String {
        switch keyCode {
        case 49:
            return "Space"
        case 36:
            return "Return"
        case 51:
            return "Delete"
        case 117:
            return "Forward Delete"
        default:
            return keyScalar(for: keyCode) ?? "Key \(keyCode)"
        }
    }

    private func keyScalar(for keyCode: Int) -> String? {
        let map: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
            39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        ]
        return map[keyCode]
    }
}

private struct EmptyChartState: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
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
