import SwiftUI

/// Product thumbnail with a graceful fallback (nil URL, load failure, offline) to a placeholder
/// shape/color — same size either way, so nothing shifts layout. Shared across every row that
/// shows a food: Add Food's search/recents lists, a meal's logged entries, and the Dashboard's
/// per-meal-slot summary row.
struct FoodThumbnailView<S: Shape>: View {
    let urlString: String?
    let shape: S
    let placeholderColor: Color
    var size: CGFloat = 36

    var body: some View {
        AsyncImage(url: urlString.flatMap(URL.init(string:))) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                shape.fill(placeholderColor)
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }
}
