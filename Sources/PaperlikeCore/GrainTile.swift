import Foundation

/// Describes one grain tile. Hashable so callers can cache generated tiles.
public struct GrainTileSpec: Hashable, Sendable {
    /// Requested tile edge length in device pixels. The actual edge is the
    /// largest multiple of `grainSize` that fits, so the tile always contains
    /// whole grains and repeats seamlessly.
    public var size: Int
    /// Edge length of one grain in device pixels (1 to 3 in the UI).
    public var grainSize: Int
    /// 0 = monochrome grain (R = G = B), 1 = fully independent RGB noise.
    public var colour: Double
    /// Standard deviation of the noise in 8-bit units around mid-grey.
    public var contrast: Double
    public var seed: UInt64

    public init(
        size: Int = 240,
        grainSize: Int = 1,
        colour: Double = 0.7,
        contrast: Double = 48,
        seed: UInt64 = 0x5EED_5EED_5EED_5EED
    ) {
        self.size = size
        self.grainSize = grainSize
        self.colour = colour
        self.contrast = contrast
        self.seed = seed
    }
}

/// An RGBA8 pixel buffer, row-major, top-left origin, alpha always 255.
public struct GrainTile: Equatable {
    public let width: Int
    public let height: Int
    public let pixels: [UInt8]

    public var bytesPerRow: Int { width * 4 }

    /// Returns the (r, g, b) of the pixel at (x, y).
    public func rgb(x: Int, y: Int) -> (UInt8, UInt8, UInt8) {
        let i = (y * width + x) * 4
        return (pixels[i], pixels[i + 1], pixels[i + 2])
    }

    public static func generate(_ spec: GrainTileSpec) -> GrainTile {
        let grain = max(1, spec.grainSize)
        let cells = max(1, spec.size / grain)
        let edge = cells * grain
        let k = min(1.0, max(0.0, spec.colour))
        // Mix weights for the shared luma sample and the per-channel sample,
        // normalised so the result always has standard deviation `contrast`
        // no matter where the colour slider sits.
        let norm = ((1 - k) * (1 - k) + k * k).squareRoot()
        let wl = (1 - k) / norm
        let wc = k / norm

        var rng = SplitMix64(seed: spec.seed)
        var pixels = [UInt8](repeating: 255, count: edge * edge * 4)

        for cy in 0..<cells {
            for cx in 0..<cells {
                // One shared luminance sample, three independent chroma
                // samples. `k` mixes between them. Sampling all four every
                // time keeps the stream position independent of `k`, so
                // changing only the colour slider keeps the same grain layout.
                let luma = rng.nextGaussian()
                let cr = rng.nextGaussian()
                let cg = rng.nextGaussian()
                let cb = rng.nextGaussian()

                let r = Self.quantise(128.0 + spec.contrast * (wl * luma + wc * cr))
                let g = Self.quantise(128.0 + spec.contrast * (wl * luma + wc * cg))
                let b = Self.quantise(128.0 + spec.contrast * (wl * luma + wc * cb))

                let x0 = cx * grain
                let y0 = cy * grain
                for y in y0..<(y0 + grain) {
                    var i = (y * edge + x0) * 4
                    for _ in 0..<grain {
                        pixels[i] = r
                        pixels[i + 1] = g
                        pixels[i + 2] = b
                        // pixels[i + 3] already 255
                        i += 4
                    }
                }
            }
        }

        return GrainTile(width: edge, height: edge, pixels: pixels)
    }

    @inline(__always)
    private static func quantise(_ v: Double) -> UInt8 {
        UInt8(min(255.0, max(0.0, v.rounded())))
    }
}
