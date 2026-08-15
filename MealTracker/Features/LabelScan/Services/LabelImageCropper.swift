import UIKit

enum LabelImageCropper {
    /// Converts a guide rectangle drawn in on-screen point space into the corresponding region
    /// of the full-resolution captured image, accounting for `.resizeAspectFill` video gravity:
    /// the preview scales the image up until it fills the screen in both dimensions, centers it,
    /// and clips whatever overflows — so this isn't a simple linear scale without first
    /// re-deriving that same fill transform. Pulled out as pure CGRect/CGSize math (no UIImage
    /// rendering) so it's unit-testable without real image assets.
    static func imageSpaceRect(forGuideRect guideRect: CGRect, screenSize: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, screenSize.width > 0, screenSize.height > 0 else {
            return .zero
        }
        let scale = max(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let imageOrigin = CGPoint(
            x: (screenSize.width - scaledImageSize.width) / 2,
            y: (screenSize.height - scaledImageSize.height) / 2
        )

        let rect = CGRect(
            x: (guideRect.minX - imageOrigin.x) / scale,
            y: (guideRect.minY - imageOrigin.y) / scale,
            width: guideRect.width / scale,
            height: guideRect.height / scale
        )
        return rect.intersection(CGRect(origin: .zero, size: imageSize))
    }

    /// Crops `image` to the region corresponding to `guideRect` as drawn over a `screenSize`
    /// preview. Nil if the computed region is empty (e.g. a degenerate guide rect).
    static func crop(image: UIImage, toGuideRect guideRect: CGRect, screenSize: CGSize) -> UIImage? {
        let rect = imageSpaceRect(forGuideRect: guideRect, screenSize: screenSize, imageSize: image.size)
        guard rect.width > 0, rect.height > 0 else { return nil }

        // Redraw through UIGraphicsImageRenderer (rather than cropping the CGImage directly) so
        // the crop respects UIImage.imageOrientation instead of the raw, unrotated pixel buffer.
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { _ in
            image.draw(at: CGPoint(x: -rect.minX, y: -rect.minY))
        }
    }
}
