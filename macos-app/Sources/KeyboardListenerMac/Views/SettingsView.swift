import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    @State private var apiBaseURL = ""
    @State private var bootstrapSecret = ""

    var body: some View {
        GroupBox("Configuration") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("API Base URL", text: $apiBaseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("Bootstrap Secret", text: $bootstrapSecret)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button("Save") {
                        appState.saveConfig(apiBaseURL: apiBaseURL, bootstrapSecret: bootstrapSecret)
                    }
                    Button("Refresh Access") {
                        appState.refreshPermissions()
                    }
                    Spacer()
                    Text(appState.config.deviceToken == nil ? "Device not registered" : "Device registered")
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                apiBaseURL = appState.config.apiBaseURL
                bootstrapSecret = appState.config.bootstrapSecret
            }
        }
    }
}
