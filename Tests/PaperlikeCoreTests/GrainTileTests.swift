import XCTest
@testable import PaperlikeCore

final class GrainTileTests: XCTestCase {
    func testDeterministicForSameSeed() {
        let a = GrainTile.generate(GrainTileSpec(seed: 42))
        let b = GrainTile.generate(GrainTileSpec(seed: 42))
        XCTAssertEqual(a, b)
    }

    func testDifferentSeedsDiffer() {
        let a = GrainTile.generate(GrainTileSpec(seed: 1))
        let b = GrainTile.generate(GrainTileSpec(seed: 2))
        XCTAssertNotEqual(a.pixels, b.pixels)
    }

    func testDimensionsAndAlpha() {
        let tile = GrainTile.generate(GrainTileSpec(size: 240, grainSize: 1))
        XCTAssertEqual(tile.width, 240)
        XCTAssertEqual(tile.height, 240)
        XCTAssertEqual(tile.pixels.count, 240 * 240 * 4)
        XCTAssertEqual(tile.bytesPerRow, 960)
        for i in stride(from: 3, to: tile.pixels.count, by: 4) {
            XCTAssertEqual(tile.pixels[i], 255)
        }
    }

    func testGrainSizeProducesSolidBlocksAndWholeTiles() {
        for grain in 1...3 {
            let tile = GrainTile.generate(GrainTileSpec(size: 240, grainSize: grain))
            XCTAssertEqual(tile.width % grain, 0, "tile must contain whole grains so it repeats seamlessly")
            for by in stride(from: 0, to: tile.height, by: grain) {
                for bx in stride(from: 0, to: tile.width, by: grain) {
                    let ref = tile.rgb(x: bx, y: by)
                    for y in by..<(by + grain) {
                        for x in bx..<(bx + grain) {
                            XCTAssertTrue(tile.rgb(x: x, y: y) == ref, "grain block at (\(bx),\(by)) is not solid")
                        }
                    }
                }
            }
        }
    }

    func testZeroColourIsMonochrome() {
        let tile = GrainTile.generate(GrainTileSpec(colour: 0))
        for y in 0..<tile.height {
            for x in 0..<tile.width {
                let (r, g, b) = tile.rgb(x: x, y: y)
                XCTAssertEqual(r, g)
                XCTAssertEqual(g, b)
            }
        }
    }

    func testDefaultColourIsNotMonochrome() {
        let tile = GrainTile.generate(GrainTileSpec())
        var differing = 0
        for y in 0..<tile.height {
            for x in 0..<tile.width {
                let (r, g, b) = tile.rgb(x: x, y: y)
                if r != g || g != b { differing += 1 }
            }
        }
        let fraction = Double(differing) / Double(tile.width * tile.height)
        XCTAssertGreaterThan(fraction, 0.9, "coloured grain should differ across channels almost everywhere")
    }

    func testDistributionCentredOnMidGreyWithExpectedSpread() {
        let spec = GrainTileSpec(contrast: 48)
        let tile = GrainTile.generate(spec)
        var sum = 0.0
        var sumSq = 0.0
        var n = 0.0
        for i in stride(from: 0, to: tile.pixels.count, by: 4) {
            for c in 0..<3 {
                let v = Double(tile.pixels[i + c])
                sum += v
                sumSq += v * v
                n += 1
            }
        }
        let mean = sum / n
        let std = (sumSq / n - mean * mean).squareRoot()
        XCTAssertEqual(mean, 128, accuracy: 2.0)
        // Clipping at 0/255 trims the tails a little, so allow a small drop.
        XCTAssertEqual(std, spec.contrast, accuracy: 4.0)
    }

    func testChangingColourKeepsGrainLayout() {
        // Same seed, different colour: the luminance pattern must be shared.
        let mono = GrainTile.generate(GrainTileSpec(colour: 0, seed: 7))
        let colour = GrainTile.generate(GrainTileSpec(colour: 0.3, seed: 7))
        var agree = 0
        let total = mono.width * mono.height
        for y in 0..<mono.height {
            for x in 0..<mono.width {
                let m = Int(mono.rgb(x: x, y: y).0)
                let (r, g, b) = colour.rgb(x: x, y: y)
                let avg = (Int(r) + Int(g) + Int(b)) / 3
                // Both above or both below mid-grey most of the time.
                if (m >= 128) == (avg >= 128) { agree += 1 }
            }
        }
        XCTAssertGreaterThan(Double(agree) / Double(total), 0.75)
    }
}
