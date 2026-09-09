import AppKit
import PaperlikeCore

/// One transparent, click-through window that covers one display.
/// Two static layers: a flat tint and a tiled grain pattern. Nothing here
/// redraws unless settings or display geometry change.
final class OverlayWindow: NSWindow {
    let displayID: CGDirectDisplayID

    private let tintLayer = CALayer()
    private let grainLayer = CALayer()

    /// What the layers currently show. `apply` is called on every screen
    /// parameter change (menu bar or Dock hiding, full-screen transitions),
    /// so it must be a no-op when nothing changed or the overlay blinks.
    private struct Applied: Equatable {
        let settings: FilterSettings
        let excludeFromCapture: Bool
        let scale: CGFloat
    }
    private var applied: Applied?

    init(screen: NSScreen, displayID: CGDirectDisplayID) {
        self.displayID = displayID
        super.init(contentRect: screen.frame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        isExcludedFromWindowsMenu = true
        hidesOnDeactivate = false
        level = Self.preferredLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        let content = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        content.wantsLayer = true
        content.layerContentsRedrawPolicy = .never
        content.autoresizesSubviews = true
        contentView = content

        for layer in [tintLayer, grainLayer] {
            layer.frame = content.bounds
            layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer.isOpaque = false
            layer.contentsScale = screen.backingScaleFactor
            layer.actions = ["opacity": NSNull(), "backgroundColor": NSNull(), "bounds": NSNull(), "position": NSNull()]
            content.layer?.addSublayer(layer)
        }

        setFrame(screen.frame, display: false)
    }

    /// Window level for the overlay.
    ///
    /// `.statusBar` (25) sits just above the menu bar (24) and the Dock (20)
    /// and, like the menu bar, stays visible and stationary while the window
    /// server animates a Space switch. Higher levels such as `.screenSaver`
    /// are dropped from that animation and blink for its duration.
    ///
    /// Override for experiments without rebuilding:
    ///   defaults write com.argado.paperlike windowLevel -int 1000
    ///   defaults write com.argado.paperlike windowLevel -int -1   (CGShieldingWindowLevel)
    ///   defaults delete com.argado.paperlike windowLevel
    static var preferredLevel: NSWindow.Level {
        if let raw = UserDefaults.standard.object(forKey: "windowLevel") as? Int {
            if raw == -1 { return NSWindow.Level(rawValue: Int(CGShieldingWindowLevel())) }
            return NSWindow.Level(rawValue: raw)
        }
        return .statusBar
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Borderless windows are normally left alone, but be explicit: we want
    /// to cover the menu bar area too, never the visible frame only.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    func apply(_ settings: FilterSettings, excludeFromCapture: Bool, scale: CGFloat) {
        let next = Applied(settings: settings, excludeFromCapture: excludeFromCapture, scale: scale)
        guard next != applied else { return }
        let previous = applied
        applied = next

        let wantedSharing: NSWindow.SharingType = excludeFromCapture ? .none : .readOnly
        if sharingType != wantedSharing {
            sharingType = wantedSharing
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Only touch the layer properties that actually changed. Assigning a
        // new backgroundColor (even an identical pattern) forces a redraw of
        // the whole layer, and a redraw of a full-screen pattern is visible.
        if previous?.settings.tintHex != settings.tintHex, let rgb = settings.tintRGB {
            tintLayer.backgroundColor = CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
        }
        if previous?.settings.tintStrength != settings.tintStrength {
            tintLayer.opacity = Float(settings.tintStrength)
        }

        if previous?.settings.tileSpec != settings.tileSpec || previous?.scale != scale {
            let image = GrainImageFactory.image(for: settings.tileSpec, scale: scale)
            grainLayer.backgroundColor = NSColor(patternImage: image).cgColor
        }
        if previous?.settings.grainStrength != settings.grainStrength {
            grainLayer.opacity = Float(settings.grainStrength)
        }
        if previous?.scale != scale {
            grainLayer.contentsScale = scale
            tintLayer.contentsScale = scale
        }

        CATransaction.commit()
    }

    /// No-op when the display geometry is unchanged, which is the common
    /// case for the notification that triggers it.
    func move(to screen: NSScreen) {
        guard frame != screen.frame else { return }
        setFrame(screen.frame, display: false)
    }
}
