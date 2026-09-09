import XCTest
@testable import PaperlikeCore

final class FilterSettingsTests: XCTestCase {
    func testClampingPullsValuesIntoRange() {
        let wild = FilterSettings(grainStrength: 9, grainSize: 0, grainColour: -1, tintHex: "zzz", tintStrength: 1)
        let c = wild.clamped()
        XCTAssertEqual(c.grainStrength, FilterSettings.grainStrengthRange.upperBound)
        XCTAssertEqual(c.grainSize, 1)
        XCTAssertEqual(c.grainColour, 0)
        XCTAssertEqual(c.tintStrength, FilterSettings.tintStrengthRange.upperBound)
        XCTAssertEqual(c.tintHex, FilterSettings.default.tintHex)
    }

    func testHexRoundTrip() {
        var s = FilterSettings()
        s.tintHex = "#f4eedf"
        XCTAssertEqual(s.clamped().tintHex, "F4EEDF")
        let rgb = s.tintRGB!
        XCTAssertEqual(rgb.r, 0xF4 / 255.0, accuracy: 1e-9)
        XCTAssertEqual(rgb.g, 0xEE / 255.0, accuracy: 1e-9)
        XCTAssertEqual(rgb.b, 0xDF / 255.0, accuracy: 1e-9)
        XCTAssertEqual(FilterSettings.hex(r: rgb.r, g: rgb.g, b: rgb.b), "F4EEDF")
    }

    func testPresetsAreWithinRangeAndDistinct() {
        for p in Preset.allCases {
            XCTAssertEqual(p.settings, p.settings.clamped(), "\(p) preset is out of range")
            XCTAssertEqual(Preset.matching(p.settings), p)
        }
        XCTAssertNil(Preset.matching(FilterSettings(grainStrength: 0.33)))
    }

    func testCodableRoundTrip() throws {
        let s = Preset.newsprint.settings
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(FilterSettings.self, from: data)
        XCTAssertEqual(back, s)
    }
}
