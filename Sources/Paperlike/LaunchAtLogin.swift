import Foundation
import ServiceManagement

enum LaunchAtLogin {
    /// SMAppService needs a real .app bundle. Under `swift run` there is none.
    static var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        guard isAvailable else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Paperlike: launch at login change failed: \(error)")
        }
    }
}
