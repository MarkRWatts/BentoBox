import SwiftUI

/// Product thumbnail with a graceful fallback (nil URL, load failure, offline) to a placeholder
/// of the same size and shape, so nothing shifts layout. Shared across every row that shows a
/// food: Add Food's search/recents lists, a meal's logged entries, and the Dashboard's per-meal
/// summary row.
///
/// Takes a corner radius rather than a `Shape` (pass `size / 2` for a circle) because the crop
/// and the rounding are baked into the cached bitmap by `FoodImageCache` — a row then draws a
/// flat image with no live mask, which is what the cell has to re-rasterise when a swipe animates
/// its corners.
struct FoodThumbnailView: View {
    let urlString: String?
    let cornerRadius: CGFloat
    let placeholderColor: Color
    var size: CGFloat = 36

    @State private var image: UIImage?

    init(urlString: String?, cornerRadius: CGFloat, placeholderColor: Color, size: CGFloat = 36) {
        self.urlString = urlString
        self.cornerRadius = cornerRadius
        self.placeholderColor = placeholderColor
        self.size = size
        // Seeded from the cache so an already-loaded image is there on the first frame, instead
        // of the placeholder flashing every time a row scrolls back into view.
        _image = State(initialValue: urlString.flatMap {
            FoodImageCache.shared.cachedImage(for: $0, size: size, cornerRadius: cornerRadius)
        })
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable()
            } else {
                RoundedRectangle(cornerRadius: cornerRadius).fill(placeholderColor)
            }
        }
        .frame(width: size, height: size)
        .task(id: urlString) {
            guard image == nil, let urlString else { return }
            image = await FoodImageCache.shared.image(for: urlString, size: size, cornerRadius: cornerRadius)
        }
    }
}
