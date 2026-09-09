import AppKit
import Carbon
import PaperlikeCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore.shared
    private var overlay: OverlayController!
    private var statusItem: StatusItemController!
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlay = OverlayController(store: store)
        statusItem = StatusItemController(store: store, overlay: overlay)

        // ⌃⌥⌘P. Carbon hot keys need no Accessibility permission.
        hotKey = GlobalHotKey(keyCode: UInt32(kVK_ANSI_P),
                              modifiers: UInt32(controlKey | optionKey | cmdKey)) { [weak self] in
            self?.store.isEnabled.toggle()
        }

        overlay.sync(animated: false)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Gamma tables revert when the process exits anyway, but be explicit.
        CGDisplayRestoreColorSyncSettings()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
