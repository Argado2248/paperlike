import AppKit
import PaperlikeCore

/// A small utility panel with live sliders. Every change writes to the store
/// immediately, so the overlay updates while you drag.
final class SettingsPanel: NSPanel {
    private let store: SettingsStore

    private let presetPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let grainStrength = NSSlider()
    private let grainColour = NSSlider()
    private let grainSize = NSSegmentedControl(labels: ["1 px", "2 px", "3 px"], trackingMode: .selectOne, target: nil, action: nil)
    private let tintWell = NSColorWell()
    private let tintStrength = NSSlider()
    private let grainStrengthValue = NSTextField(labelWithString: "")
    private let grainColourValue = NSTextField(labelWithString: "")
    private let tintStrengthValue = NSTextField(labelWithString: "")
    private let excludeCheckbox = NSButton(checkboxWithTitle: "Hide from screenshots and recordings", target: nil, action: nil)
    private let loginCheckbox = NSButton(checkboxWithTitle: "Launch at login", target: nil, action: nil)

    private var observer: NSObjectProtocol?
    private var isUpdatingFromStore = false

    init(store: SettingsStore) {
        self.store = store
        super.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
                   styleMask: [.titled, .closable, .utilityWindow],
                   backing: .buffered,
                   defer: false)
        title = "Paperlike"
        isReleasedWhenClosed = false
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        level = .floating

        buildUI()
        loadFromStore()
        center()

        observer = NotificationCenter.default.addObserver(forName: SettingsStore.didChange,
                                                          object: store, queue: .main) { [weak self] _ in
            self?.loadFromStore()
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    // MARK: UI

    private func buildUI() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        presetPopup.addItems(withTitles: Preset.allCases.map(\.title) + ["Custom"])
        presetPopup.target = self
        presetPopup.action = #selector(presetChanged(_:))
        stack.addArrangedSubview(row("Preset", presetPopup))

        configure(grainStrength, range: FilterSettings.grainStrengthRange, action: #selector(valueChanged(_:)))
        stack.addArrangedSubview(row("Grain", grainStrength, value: grainStrengthValue))

        configure(grainColour, range: FilterSettings.grainColourRange, action: #selector(valueChanged(_:)))
        stack.addArrangedSubview(row("Grain colour", grainColour, value: grainColourValue))

        grainSize.target = self
        grainSize.action = #selector(valueChanged(_:))
        stack.addArrangedSubview(row("Grain size", grainSize))

        tintWell.target = self
        tintWell.action = #selector(valueChanged(_:))
        tintWell.widthAnchor.constraint(equalToConstant: 44).isActive = true
        tintWell.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(row("Tint", tintWell))

        configure(tintStrength, range: FilterSettings.tintStrengthRange, action: #selector(valueChanged(_:)))
        stack.addArrangedSubview(row("Tint strength", tintStrength, value: tintStrengthValue))

        stack.addArrangedSubview(NSBox.separatorLine())

        excludeCheckbox.target = self
        excludeCheckbox.action = #selector(excludeChanged(_:))
        stack.addArrangedSubview(excludeCheckbox)

        loginCheckbox.target = self
        loginCheckbox.action = #selector(loginChanged(_:))
        loginCheckbox.isEnabled = LaunchAtLogin.isAvailable
        stack.addArrangedSubview(loginCheckbox)

        let hint = NSTextField(labelWithString: "Toggle anywhere with ⌃⌥⌘P or by clicking the menu bar icon.")
        hint.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor
        stack.addArrangedSubview(hint)

        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.widthAnchor.constraint(equalToConstant: 400),
        ])
        contentView = content
        setContentSize(content.fittingSize)
    }

    private func configure(_ slider: NSSlider, range: ClosedRange<Double>, action: Selector) {
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.isContinuous = true
        slider.target = self
        slider.action = action
        slider.widthAnchor.constraint(equalToConstant: 200).isActive = true
    }

    private func row(_ title: String, _ control: NSView, value: NSTextField? = nil) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 100).isActive = true
        var views: [NSView] = [label, control]
        if let value {
            value.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            value.textColor = .secondaryLabelColor
            value.alignment = .right
            value.widthAnchor.constraint(equalToConstant: 36).isActive = true
            views.append(value)
        }
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        return row
    }

    // MARK: Store <-> UI

    private func loadFromStore() {
        isUpdatingFromStore = true
        defer { isUpdatingFromStore = false }

        let f = store.filter
        grainStrength.doubleValue = f.grainStrength
        grainColour.doubleValue = f.grainColour
        grainSize.selectedSegment = max(0, min(2, f.grainSize - 1))
        tintStrength.doubleValue = f.tintStrength
        updateValueLabels(f)
        if let rgb = f.tintRGB {
            tintWell.color = NSColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
        }
        if let preset = Preset.matching(f), let index = Preset.allCases.firstIndex(of: preset) {
            presetPopup.selectItem(at: index)
        } else {
            presetPopup.selectItem(at: Preset.allCases.count) // Custom
        }
        excludeCheckbox.state = store.excludeFromCapture ? .on : .off
        loginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    private func updateValueLabels(_ f: FilterSettings) {
        grainStrengthValue.stringValue = String(format: "%.2f", f.grainStrength)
        grainColourValue.stringValue = String(format: "%.2f", f.grainColour)
        tintStrengthValue.stringValue = String(format: "%.2f", f.tintStrength)
    }

    @objc private func presetChanged(_ sender: NSPopUpButton) {
        guard !isUpdatingFromStore else { return }
        let index = sender.indexOfSelectedItem
        guard index < Preset.allCases.count else { return } // "Custom": leave as is
        store.filter = Preset.allCases[index].settings
    }

    @objc private func valueChanged(_ sender: Any?) {
        guard !isUpdatingFromStore else { return }
        var f = store.filter
        f.grainStrength = grainStrength.doubleValue
        f.grainColour = grainColour.doubleValue
        f.grainSize = grainSize.selectedSegment + 1
        f.tintStrength = tintStrength.doubleValue
        if let c = tintWell.color.usingColorSpace(.sRGB) {
            f.tintHex = FilterSettings.hex(r: c.redComponent, g: c.greenComponent, b: c.blueComponent)
        }
        store.filter = f
    }

    @objc private func excludeChanged(_ sender: NSButton) {
        guard !isUpdatingFromStore else { return }
        store.excludeFromCapture = sender.state == .on
    }

    @objc private func loginChanged(_ sender: NSButton) {
        guard !isUpdatingFromStore else { return }
        LaunchAtLogin.set(sender.state == .on)
    }
}

private extension NSBox {
    static func separatorLine() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 368).isActive = true
        return box
    }
}
