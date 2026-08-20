import SwiftUI

/// Product thumbnail with a graceful fallback (nil URL, load failure, offline) to a placeholder
/// shape/color — same size either way, so nothing shifts layout. Shared across every row that
/// shows a food: Add Food's search/recents lists, a meal's logged entries, and the Dashboard's
/// per-meal-slot summary row.
///
/// Backed by `FoodImageCache` rather than `AsyncImage`: see that type for why re-decoding these
/// on every appearance was costing frames on a real log.
struct FoodThumbnailView<S: Shape>: View {
    let urlString: String?
    let shape: S
    let placeholderColor: Color
    var size: CGFloat = 36

    @State private var image: UIImage?

    init(urlString: String?, shape: S, placeholderColor: Color, size: CGFloat = 36) {
        self.urlString = urlString
        self.shape = shape
        self.placeholderColor = placeholderColor
        self.size = size
        // Seeded from the cache so an already-loaded image is there on the first frame, instead
        // of the placeholder flashing every time a row scrolls back into view.
        _image = State(initialValue: urlString.flatMap { FoodImageCache.shared.cachedImage(for: $0, size: size) })
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                shape.fill(placeholderColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .task(id: urlString) {
            guard image == nil, let urlString else { return }
            image = await FoodImageCache.shared.image(for: urlString, size: size)
        }
    }
}
