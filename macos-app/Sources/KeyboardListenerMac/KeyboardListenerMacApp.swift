import AppKit
import SwiftUI

@main
struct KeyboardListenerMacApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("Keyboard Listener", systemImage: appState.isListening ? "keyboard.badge.eye" : "keyboard") {
            VStack(alignment: .leading, spacing: 10) {
                Text(appState.isListening ? "Listening" : "Paused")
                    .font(.headline)
                Text("Today: \(appState.todayCount)")
                    .foregroundStyle(.secondary)
                Text("Pending upload: \(appState.pendingUploadCount)")
                    .foregroundStyle(.secondary)

                Divider()

                Button(appState.isListening ? "Pause Listening" : "Start Listening") {
                    appState.toggleListening()
                }
                Button("Sync Now") {
                    appState.syncNow()
                }
                Button("Open Dashboard") {
                    openWindow(id: "dashboard")
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(8)
        }

        WindowGroup("Dashboard", id: "dashboard") {
            DashboardView(appState: appState)
        }
        .defaultSize(width: 760, height: 720)
    }
}
