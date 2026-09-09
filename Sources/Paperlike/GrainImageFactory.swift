import AppKit
import PaperlikeCore

/// Turns a grain tile into an NSImage sized in points so that one tile pixel
/// lands on exactly one device pixel at the given backing scale.
enum GrainImageFactory {
    private struct CacheKey: Hashable {
        let spec: GrainTileSpec
        let scale: CGFloat
    }

    private static var cache: [CacheKey: NSImage] = [:]

    static func image(for spec: GrainTileSpec, scale: CGFloat) -> NSImage {
        let key = CacheKey(spec: spec, scale: scale)
        if let cached = cache[key] { return cached }

        let tile = GrainTile.generate(spec)
        let cgImage = makeCGImage(tile)
        let pointSize = NSSize(width: CGFloat(tile.width) / scale,
                               height: CGFloat(tile.height) / scale)
        let image = NSImage(cgImage: cgImage, size: pointSize)

        // Keep the cache tiny: at most a handful of (spec, scale) pairs live.
        if cache.count > 8 { cache.removeAll() }
        cache[key] = image
        return image
    }

    private static func makeCGImage(_ tile: GrainTile) -> CGImage {
        let data = Data(tile.pixels) as CFData
        let provider = CGDataProvider(data: data)!
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        // RGBA8 with alpha fixed at 255: tell CG to skip the last byte.
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
            .union(.byteOrder32Big)
        return CGImage(
            width: tile.width,
            height: tile.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: tile.bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }
}
