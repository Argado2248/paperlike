import AppKit
import PaperlikeCore

/// The menu bar icon. Left click toggles the filter, right click (or
/// option-click) opens the menu.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let store: SettingsStore
    private let overlay: OverlayController
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var settingsPanel: SettingsPanel?
    private var observer: NSObjectProtocol?

    private let onImage = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: "Paperlike on")
    private let offImage = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "Paperlike off")

    init(store: SettingsStore, overlay: OverlayController) {
        self.store = store
        self.overlay = overlay
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        onImage?.isTemplate = true
        offImage?.isTemplate = true

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusButtonClicked(_:))
            _ = button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Paperlike — click to toggle, right-click for options (⌃⌥⌘P)"
        }

        menu.delegate = self
        menu.autoenablesItems = false
        buildMenu()
        refreshIcon()

        observer = NotificationCenter.default.addObserver(forName: SettingsStore.didChange,
                                                          object: store, queue: .main) { [weak self] _ in
            self?.refreshIcon()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: Actions

    @objc private func statusButtonClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.option) == true
        if wantsMenu {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil // so the next left click toggles again
        } else {
            store.isEnabled.toggle()
        }
    }

    @objc private func toggle(_ sender: Any?) {
        store.isEnabled.toggle()
    }

    @objc private func choosePreset(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let preset = Preset(rawValue: raw) else { return }
        store.filter = preset.settings
    }

    @objc private func openSettings(_ sender: Any?) {
        if settingsPanel == nil {
            settingsPanel = SettingsPanel(store: store)
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsPanel?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleExcludeFromCapture(_ sender: Any?) {
        store.excludeFromCapture.toggle()
    }

    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    // MARK: Menu

    private func buildMenu() {
        menu.removeAllItems()

        let toggleItem = NSMenuItem(title: "Turn Paperlike On", action: #selector(toggle(_:)), keyEquivalent: "p")
        toggleItem.keyEquivalentModifierMask = [.control, .option, .command]
        toggleItem.target = self
        toggleItem.tag = Tag.toggle
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let presets = NSMenu(title: "Preset")
        for preset in Preset.allCases {
            let item = NSMenuItem(title: preset.title, action: #selector(choosePreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.rawValue
            presets.addItem(item)
        }
        let presetsItem = NSMenuItem(title: "Preset", action: nil, keyEquivalent: "")
        presetsItem.submenu = presets
        presetsItem.tag = Tag.presets
        menu.addItem(presetsItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings(_:)), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let excludeItem = NSMenuItem(title: "Hide from Screenshots and Recordings",
                                     action: #selector(toggleExcludeFromCapture(_:)), keyEquivalent: "")
        excludeItem.target = self
        excludeItem.tag = Tag.exclude
        menu.addItem(excludeItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        loginItem.target = self
        loginItem.tag = Tag.login
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Paperlike", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Diagnostics: which window level and collection behaviour this
        // running instance is actually using. Disabled, informational only.
        let info = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        info.isEnabled = false
        info.tag = Tag.info
        menu.addItem(info)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
        menu.item(withTag: Tag.info)?.title = String(
            format: "v%@ · level %d · behavior %lu",
            version, OverlayWindow.preferredLevel.rawValue, OverlayWindow.preferredCollectionBehavior.rawValue)
        menu.item(withTag: Tag.toggle)?.title = store.isEnabled ? "Turn Paperlike Off" : "Turn Paperlike On"
        menu.item(withTag: Tag.exclude)?.state = store.excludeFromCapture ? .on : .off

        if let login = menu.item(withTag: Tag.login) {
            login.isEnabled = LaunchAtLogin.isAvailable
            login.state = LaunchAtLogin.isEnabled ? .on : .off
        }

        let current = Preset.matching(store.filter)
        menu.item(withTag: Tag.presets)?.submenu?.items.forEach { item in
            item.state = (item.representedObject as? String) == current?.rawValue ? .on : .off
        }
    }

    private func refreshIcon() {
        statusItem.button?.image = store.isEnabled ? onImage : offImage
        statusItem.button?.appearsDisabled = false
    }

    private enum Tag {
        static let toggle = 1
        static let presets = 2
        static let exclude = 3
        static let login = 4
        static let info = 5
    }
}
