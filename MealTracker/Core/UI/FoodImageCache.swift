import ImageIO
import UIKit

/// In-memory cache of thumbnail-sized product images, shared by every `FoodThumbnailView`.
///
/// `AsyncImage` (what this replaces) re-fetches and re-decodes on every appearance and keeps
/// nothing but `URLCache`'s copy of the *encoded* bytes, so a screen of logged food decoded
/// full-size product photos on the main thread each time it appeared — cheap enough to miss in a
/// simulator with no image URLs, and very visible as swipe/scroll hitching on a real log at 120Hz.
///
/// Two things fix that: images are decoded once and kept as ready-to-draw `UIImage`s, and they're
/// downsampled to the size actually drawn (a 40pt thumbnail from a 1000px photo) rather than
/// decoded at full resolution and scaled down at draw time.
final class FoodImageCache: @unchecked Sendable {
    static let shared = FoodImageCache()

    private let cache = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    /// De-duplicates concurrent loads of the same image — the same food often appears in several
    /// rows at once (a recipe's ingredients, a day of repeated snacks).
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 300
    }

    /// Synchronous cache read, so a view that already has its image can show it on the very first
    /// frame instead of flashing its placeholder.
    func cachedImage(for urlString: String, size: CGFloat) -> UIImage? {
        cache.object(forKey: Self.key(urlString, size) as NSString)
    }

    func image(for urlString: String, size: CGFloat) async -> UIImage? {
        let key = Self.key(urlString, size)
        if let cached = cache.object(forKey: key as NSString) { return cached }

        let task = existingOrStartedTask(for: key) {
            Task.detached(priority: .utility) { [self] () -> UIImage? in
                guard let url = URL(string: urlString),
                      let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = Self.downsample(data, to: size) else { return nil }
                cache.setObject(image, forKey: key as NSString)
                return image
            }
        }

        let image = await task.value
        finish(key)
        return image
    }

    // The lock lives in these synchronous helpers rather than in `image(for:size:)` itself:
    // `NSLock` can't be taken from an async context under Swift 6 strict concurrency, and this
    // shape also makes it plain that the lock is never held across the `await`.
    private func existingOrStartedTask(
        for key: String,
        start: () -> Task<UIImage?, Never>
    ) -> Task<UIImage?, Never> {
        lock.lock()
        defer { lock.unlock() }
        if let existing = inFlight[key] { return existing }
        let task = start()
        inFlight[key] = task
        return task
    }

    private func finish(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        inFlight[key] = nil
    }

    /// Sized for the densest screen rather than the current one, so the cache key stays a plain
    /// point size and one cached copy serves every device scale. At thumbnail sizes the extra
    /// pixels are negligible.
    private static let maxDisplayScale: CGFloat = 3

    private static func key(_ urlString: String, _ size: CGFloat) -> String {
        "\(urlString)|\(Int(size))"
    }

    /// Decodes straight to the drawn size via ImageIO. `shouldCacheImmediately` forces the decode
    /// to happen here — on this background task — rather than lazily on the main thread the first
    /// time the image is drawn, which is the part that shows up as a dropped frame.
    private static func downsample(_ data: Data, to size: CGFloat) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: size * maxDisplayScale
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: thumbnail)
    }
}
