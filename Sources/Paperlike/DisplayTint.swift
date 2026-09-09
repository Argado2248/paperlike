import AppKit
import CoreGraphics
import PaperlikeCore

/// Applies the paper tint through each display's gamma table instead of an
/// overlay window. The table is applied at the display output, so it covers
/// the menu bar, Dock, Space-switch animations and full-screen apps, never
/// blinks, costs nothing per frame, and is excluded from screenshots.
///
/// The maths reproduce the old overlay exactly: an overlay blended
/// `(1 - a) * pixel + a * tint` before the display's own transfer curve g,
/// so the new table is `g((1 - a) * x + a * tint)` sampled from the base
/// table that ColorSync installed for the display profile.
final class DisplayTint {
    private struct Table {
        var red: [CGGammaValue]
        var green: [CGGammaValue]
        var blue: [CGGammaValue]
    }

    private var baseTables: [CGDirectDisplayID: Table] = [:]
    private var current: FilterSettings?
    private var isActive = false
    private var reconfigurePending = false
    private var wakeObserver: NSObjectProtocol?

    /// Kept in a static so registration and removal use the same pointer.
    private static let reconfigurationCallback: CGDisplayReconfigurationCallBack = { _, flags, userInfo in
        guard let userInfo, !flags.contains(.beginConfigurationFlag) else { return }
        let me = Unmanaged<DisplayTint>.fromOpaque(userInfo).takeUnretainedValue()
        DispatchQueue.main.async { me.displaysDidReconfigure() }
    }

    init() {
        readBaseTables()
        CGDisplayRegisterReconfigurationCallback(Self.reconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.reapply()
        }
    }

    deinit {
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        CGDisplayRemoveReconfigurationCallback(Self.reconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
        restore()
    }

    // MARK: Public

    /// Turn the tint on with `settings`, or off with `nil`.
    func set(_ settings: FilterSettings?) {
        guard let settings, settings.tintStrength > 0, settings.tintRGB != nil else {
            current = nil
            if isActive { restore() }
            return
        }
        guard settings != current || !isActive else { return }
        current = settings
        apply(settings)
    }

    // MARK: Internals

    private func displaysDidReconfigure() {
        // Reconfiguration callbacks arrive in bursts; coalesce them.
        guard !reconfigurePending else { return }
        reconfigurePending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.reconfigurePending = false
            self.readBaseTables()
            self.reapply()
        }
    }

    private func reapply() {
        if let current { apply(current) }
    }

    private func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return Array(ids.prefix(Int(count)))
    }

    /// Reset every display to its ColorSync profile and record the tables
    /// that gives us. Those are the curves we blend on top of.
    private func readBaseTables() {
        CGDisplayRestoreColorSyncSettings()
        baseTables.removeAll()
        let capacity: UInt32 = 256
        for id in activeDisplays() {
            var red = [CGGammaValue](repeating: 0, count: Int(capacity))
            var green = red
            var blue = red
            var count: UInt32 = 0
            let status = CGGetDisplayTransferByTable(id, capacity, &red, &green, &blue, &count)
            guard status == .success, count > 1 else { continue }
            let n = Int(count)
            baseTables[id] = Table(red: Array(red.prefix(n)), green: Array(green.prefix(n)), blue: Array(blue.prefix(n)))
        }
    }

    private func apply(_ settings: FilterSettings) {
        guard let tint = settings.tintRGB else { return }
        let a = CGGammaValue(settings.tintStrength)
        let target = (CGGammaValue(tint.r), CGGammaValue(tint.g), CGGammaValue(tint.b))

        for (id, base) in baseTables {
            let n = base.red.count
            var red = [CGGammaValue](repeating: 0, count: n)
            var green = red
            var blue = red
            for i in 0..<n {
                let x = CGGammaValue(i) / CGGammaValue(n - 1)
                red[i] = Self.sample(base.red, at: (1 - a) * x + a * target.0)
                green[i] = Self.sample(base.green, at: (1 - a) * x + a * target.1)
                blue[i] = Self.sample(base.blue, at: (1 - a) * x + a * target.2)
            }
            if CGSetDisplayTransferByTable(id, UInt32(n), red, green, blue) == .success {
                isActive = true
            }
        }
    }

    private func restore() {
        CGDisplayRestoreColorSyncSettings()
        isActive = false
    }

    /// Linear interpolation into a gamma table at a normalised position.
    private static func sample(_ table: [CGGammaValue], at v: CGGammaValue) -> CGGammaValue {
        let clamped = min(1, max(0, v))
        let pos = clamped * CGGammaValue(table.count - 1)
        let lo = Int(pos)
        let hi = min(lo + 1, table.count - 1)
        let frac = pos - CGGammaValue(lo)
        return table[lo] + (table[hi] - table[lo]) * frac
    }
}
