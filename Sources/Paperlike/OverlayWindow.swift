import AppKit
import PaperlikeCore

/// One transparent, click-through window that covers one display.
/// Two static layers: a flat tint and a tiled grain pattern. Nothing here
/// redraws unless settings or display geometry change.
final class OverlayWindow: NSWindow {
    let displayID: CGDirectDisplayID

    private let tintLayer = CALayer()
    private let grainLayer = CALayer()

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
        // Above the menu bar (24) and Dock (20), below the shield used for
        // secure dialogs and the login window.
        level = .screenSaver
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

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Borderless windows are normally left alone, but be explicit: we want
    /// to cover the menu bar area too, never the visible frame only.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    func apply(_ settings: FilterSettings, excludeFromCapture: Bool, scale: CGFloat) {
        sharingType = excludeFromCapture ? .none : .readOnly

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if let rgb = settings.tintRGB {
            tintLayer.backgroundColor = CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
        }
        tintLayer.opacity = Float(settings.tintStrength)

        let image = GrainImageFactory.image(for: settings.tileSpec, scale: scale)
        grainLayer.backgroundColor = NSColor(patternImage: image).cgColor
        grainLayer.opacity = Float(settings.grainStrength)
        grainLayer.contentsScale = scale
        tintLayer.contentsScale = scale

        CATransaction.commit()
    }

    func move(to screen: NSScreen) {
        setFrame(screen.frame, display: false)
    }
}
