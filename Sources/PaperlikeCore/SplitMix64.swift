import Foundation

/// Small, fast, seedable PRNG. Deterministic across platforms, which is what
/// the grain tile needs: same seed, same paper, every launch.
public struct SplitMix64 {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in the half-open range (0, 1]. Never returns 0, so it is safe
    /// to feed straight into a logarithm.
    public mutating func nextUnit() -> Double {
        let bits = next() >> 11 // 53 random bits
        return (Double(bits) + 1.0) / 9_007_199_254_740_992.0 // 2^53
    }

    /// Standard normal sample via Box-Muller.
    public mutating func nextGaussian() -> Double {
        let u1 = nextUnit()
        let u2 = nextUnit()
        return (-2.0 * log(u1)).squareRoot() * cos(2.0 * Double.pi * u2)
    }
}
