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
                Toggle("启动时默认开启", isOn: Binding(
                    get: { appState.config.startListeningOnLaunch },
                    set: { appState.setStartListeningOnLaunch($0) }
                ))
                Text("开启后应用启动会自动进入监听状态。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Open at Login", isOn: Binding(
                    get: { appState.launchAtLoginEnabled },
                    set: { appState.setLaunchAtLoginEnabled($0) }
                ))
                .disabled(!appState.launchAtLoginSupported)
                HStack {
                    Button("Save") {
                        appState.saveConfig(apiBaseURL: apiBaseURL, bootstrapSecret: bootstrapSecret)
                    }
                    Button("Refresh Access") {
                        appState.refreshPermissions()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(appState.config.deviceToken == nil ? "Device not registered" : "Device registered")
                        Text(appState.launchAtLoginSupported ? "Packaged app detected" : "Use the .app bundle for login items")
                    }
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
