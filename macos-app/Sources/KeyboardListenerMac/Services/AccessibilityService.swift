import ApplicationServices
import Foundation

@MainActor
enum AccessibilityService {
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func promptForAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
