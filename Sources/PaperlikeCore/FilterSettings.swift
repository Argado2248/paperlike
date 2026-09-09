import Foundation

/// Everything that decides how the paper looks. Pure data.
public struct FilterSettings: Codable, Equatable, Sendable {
    public var grainStrength: Double
    public var grainSize: Int
    public var grainColour: Double
    /// Six hex digits, no leading '#'.
    public var tintHex: String
    public var tintStrength: Double

    public static let grainStrengthRange: ClosedRange<Double> = 0.0...0.30
    public static let grainSizeRange: ClosedRange<Int> = 1...3
    public static let grainColourRange: ClosedRange<Double> = 0.0...1.0
    public static let tintStrengthRange: ClosedRange<Double> = 0.0...0.15

    public init(
        grainStrength: Double = 0.05,
        grainSize: Int = 1,
        grainColour: Double = 0.0,
        tintHex: String = "F4EEDF",
        tintStrength: Double = 0.03
    ) {
        self.grainStrength = grainStrength
        self.grainSize = grainSize
        self.grainColour = grainColour
        self.tintHex = tintHex
        self.tintStrength = tintStrength
    }

    public static let `default` = FilterSettings()

    /// Returns a copy with every value forced into its allowed range and the
    /// tint normalised to six upper-case hex digits.
    public func clamped() -> FilterSettings {
        var c = self
        c.grainStrength = Self.grainStrengthRange.clamp(grainStrength)
        c.grainSize = Self.grainSizeRange.clamp(grainSize)
        c.grainColour = Self.grainColourRange.clamp(grainColour)
        c.tintStrength = Self.tintStrengthRange.clamp(tintStrength)
        c.tintHex = Self.normaliseHex(tintHex) ?? Self.default.tintHex
        return c
    }

    /// Tint colour as sRGB components in 0...1, or nil if the hex is invalid.
    public var tintRGB: (r: Double, g: Double, b: Double)? {
        guard let hex = Self.normaliseHex(tintHex), let v = UInt32(hex, radix: 16) else { return nil }
        return (
            Double((v >> 16) & 0xFF) / 255.0,
            Double((v >> 8) & 0xFF) / 255.0,
            Double(v & 0xFF) / 255.0
        )
    }

    public static func hex(r: Double, g: Double, b: Double) -> String {
        func c(_ x: Double) -> Int { Int((min(1, max(0, x)) * 255).rounded()) }
        return String(format: "%02X%02X%02X", c(r), c(g), c(b))
    }

    static func normaliseHex(_ s: String) -> String? {
        var t = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if t.hasPrefix("#") { t.removeFirst() }
        guard t.count == 6, t.allSatisfy({ $0.isHexDigit }) else { return nil }
        return t
    }

    /// The tile spec this look needs, independent of display scale.
    public var tileSpec: GrainTileSpec {
        GrainTileSpec(size: 240, grainSize: grainSize, colour: grainColour)
    }
}

public enum Preset: String, CaseIterable, Sendable {
    case paper
    case newsprint
    case offWhite

    public var title: String {
        switch self {
        case .paper: return "Paper"
        case .newsprint: return "Newsprint"
        case .offWhite: return "Off-white"
        }
    }

    public var settings: FilterSettings {
        switch self {
        case .paper:
            return .default
        case .newsprint:
            return FilterSettings(grainStrength: 0.26, grainSize: 1, grainColour: 0.5, tintHex: "E6E2D8", tintStrength: 0.12)
        case .offWhite:
            return FilterSettings(grainStrength: 0.12, grainSize: 1, grainColour: 0.7, tintHex: "F7F5F0", tintStrength: 0.06)
        }
    }

    /// The preset whose values exactly match `settings`, if any.
    public static func matching(_ settings: FilterSettings) -> Preset? {
        allCases.first { $0.settings == settings.clamped() }
    }
}

extension ClosedRange {
    func clamp(_ v: Bound) -> Bound { Swift.min(upperBound, Swift.max(lowerBound, v)) }
}
