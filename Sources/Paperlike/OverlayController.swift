import AppKit
import PaperlikeCore

/// Owns one OverlayWindow per connected display and keeps them in sync with
/// the settings store and with display hot-plug, sleep and wake.
final class OverlayController {
    private let store: SettingsStore
    private var windows: [CGDirectDisplayID: OverlayWindow] = [:]
    private(set) var isVisible = false
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    init(store: SettingsStore) {
        self.store = store
        let nc = NotificationCenter.default
        let wc = NSWorkspace.shared.notificationCenter

        observers.append((nc, nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            self?.rebuildWindows()
        }))
        observers.append((nc, nc.addObserver(forName: SettingsStore.didChange,
                                             object: store, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.setVisible(self.store.isEnabled, animated: true)
            self.applySettings()
        }))
        observers.append((wc, wc.addObserver(forName: NSWorkspace.didWakeNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            // Cheap insurance: some wake paths reorder window layers.
            self?.bringToFront()
        }))
        observers.append((wc, wc.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                                             object: nil, queue: .main) { [weak self] _ in
            self?.bringToFront()
        }))

        rebuildWindows()
        NSLog("Paperlike: overlay window level %d, collection behavior %lu",
              OverlayWindow.preferredLevel.rawValue, OverlayWindow.preferredCollectionBehavior.rawValue)
    }

    deinit {
        observers.forEach { $0.center.removeObserver($0.token) }
    }

    // MARK: Visibility

    func setVisible(_ visible: Bool, animated: Bool) {
        guard visible != isVisible else { return }
        isVisible = visible
        for window in windows.values {
            show(window, visible: visible, animated: animated)
        }
    }

    private func show(_ window: OverlayWindow, visible: Bool, animated: Bool) {
        let duration: TimeInterval = animated ? 0.12 : 0
        if visible {
            window.alphaValue = animated ? 0 : 1
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = duration
                window.animator().alphaValue = 1
            }
        } else {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = duration
                window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard let self, !self.isVisible else { return }
                window.orderOut(nil)
            })
        }
    }

    private func bringToFront() {
        guard isVisible else { return }
        windows.values.forEach { $0.orderFrontRegardless() }
    }

    // MARK: Displays

    private static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    /// Diff current screens against existing windows. Unchanged displays keep
    /// their window; only geometry and scale are refreshed.
    private func rebuildWindows() {
        var seen = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            guard let id = Self.displayID(of: screen) else { continue }
            seen.insert(id)
            if let existing = windows[id] {
                existing.move(to: screen)
            } else {
                let window = OverlayWindow(screen: screen, displayID: id)
                windows[id] = window
                if isVisible {
                    window.alphaValue = 1
                    window.orderFrontRegardless()
                }
            }
        }
        for (id, window) in windows where !seen.contains(id) {
            window.orderOut(nil)
            window.close()
            windows.removeValue(forKey: id)
        }
        applySettings()
    }

    private func applySettings() {
        let settings = store.filter
        let exclude = store.excludeFromCapture
        for screen in NSScreen.screens {
            guard let id = Self.displayID(of: screen), let window = windows[id] else { continue }
            window.apply(settings, excludeFromCapture: exclude, scale: screen.backingScaleFactor)
        }
    }
}
