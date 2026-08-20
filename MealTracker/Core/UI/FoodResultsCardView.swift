import SwiftUI

/// Uppercase label + a card of divided rows — the mockup's "You log these often" / "All results"
/// treatment, matching the Dashboard's `LoggedMealsCardView` (same index-based divider approach).
/// Shared between `AddFoodView` and `IngredientPickerView`.
struct FoodResultsCardView<Item, RowContent: View>: View {
    let title: String
    let items: [Item]
    @ViewBuilder let rowContent: (Item) -> RowContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.manrope(10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(Color.dashboardInkSecondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    rowContent(item)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                    if index < items.count - 1 {
                        Rectangle()
                            .fill(Color.dashboardDivider)
                            .frame(height: 1)
                            .padding(.leading, 15 + 36 + 12)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 22))
        }
    }
}

/// Row for a previously-logged `FoodItem` picked again from the "recent" list. Shared between
/// `AddFoodView` and `IngredientPickerView`.
struct RecentFoodRowView: View {
    let foodItem: FoodItem

    var body: some View {
        HStack(spacing: 12) {
            FoodThumbnailView(urlString: foodItem.imageURLString, shape: Circle(), placeholderColor: .dashboardBarFill)
            VStack(alignment: .leading, spacing: 2) {
                Text(foodItem.name)
                    .font(.manrope(14, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Text("\(Int(foodItem.caloriesPerServing)) cal · \(foodItem.servingSizeDescription)")
                    .font(.manrope(11, weight: .medium))
                    .foregroundStyle(Color.dashboardInkSecondary)
            }
            Spacer()
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.dashboardAccent)
        }
        .contentShape(Rectangle())
    }
}

/// Row for a `FoodSearchResult` (Open Food Facts or USDA). Shared between `AddFoodView` and
/// `IngredientPickerView`.
struct FoodSearchResultRowView: View {
    let result: FoodSearchResult

    private var subtitle: String {
        var parts: [String] = []
        if let brand = result.preview.brand, !brand.isEmpty {
            parts.append(brand)
        }
        parts.append("\(Int(result.preview.caloriesPerServing)) cal")
        parts.append(result.preview.servingSizeDescription)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            FoodThumbnailView(urlString: result.thumbnailURLString, shape: RoundedRectangle(cornerRadius: 11), placeholderColor: .dashboardBarTrack)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.preview.name)
                    .font(.manrope(14, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Text(subtitle)
                    .font(.manrope(11, weight: .medium))
                    .foregroundStyle(Color.dashboardInkSecondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}
