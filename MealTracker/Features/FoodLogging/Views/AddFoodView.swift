import SwiftUI
import SwiftData

/// Single entry point for adding food to a meal slot: search-by-name, recently-used foods for a
/// fast re-log, plus the three ways to add something new. Recency-sorted rather than tracking a
/// separate frequency count — foods you eat often keep getting bumped back to the top every time
/// you log them again, so "Recent" already reads as "Frequent" in practice.
///
/// A literal port of the Claude Design mockup's "Log food" screen (1d): a search pill paired with
/// a barcode-scan button, then card-grouped result lists. The mockup only anticipated barcode
/// scanning as a companion action — label scan, manual entry and copy-from-previous-day are real
/// features it didn't design for, so those live in a compact secondary-actions row instead.
struct AddFoodView: View {
    let mealSlot: MealSlotConfig
    var date: Date = Date()
    var onSelectBarcodeScan: () -> Void
    var onSelectLabelScan: () -> Void
    var onSelectManualEntry: () -> Void
    var onSelectCopyFromPreviousDay: () -> Void
    var onLogged: () -> Void

    @Query(sort: \FoodItem.lastUsedAt, order: .reverse) private var allFoodItems: [FoodItem]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var searchQuery = ""
    @State private var searchResults: [OFFProduct] = []
    @State private var isLoadingResults = false
    @State private var searchErrorMessage: String?
    @FocusState private var isSearchFocused: Bool
    private let client = OpenFoodFactsClient()

    private var recentItems: [FoodItem] {
        Array(allFoodItems.prefix(20))
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    searchRow
                    secondaryActionsRow

                    if trimmedQuery.isEmpty {
                        if !recentItems.isEmpty {
                            FoodResultsCardView(title: "You log these often", items: recentItems) { item in
                                NavigationLink {
                                    ProductLookupResultView(foodItem: item, mealSlot: mealSlot, date: date, onLogged: onLogged)
                                } label: {
                                    RecentFoodRowView(foodItem: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        searchResultsContent
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.dashboardCanvas)
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task(id: searchQuery) {
                await search()
            }
        }
    }

    private var searchRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.dashboardInkSecondary)
                TextField("Search foods", text: $searchQuery)
                    .font(.manrope(14, weight: .medium))
                    .foregroundStyle(Color.dashboardInk)
                    .focused($isSearchFocused)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.dashboardInkSecondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.dashboardAccentDeep.opacity(0.14)))

            Button(action: onSelectBarcodeScan) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.dashboardInk, in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel("Scan Barcode")
        }
    }

    private var secondaryActionsRow: some View {
        HStack(spacing: 10) {
            SecondaryActionButton(symbol: "text.viewfinder", title: "Scan Label", action: onSelectLabelScan)
            SecondaryActionButton(symbol: "square.and.pencil", title: "Manual", action: onSelectManualEntry)
            SecondaryActionButton(symbol: "clock.arrow.circlepath", title: "Copy Previous", action: onSelectCopyFromPreviousDay)
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        if isLoadingResults {
            ProgressView()
                .padding(.top, 40)
        } else if let searchErrorMessage {
            ContentUnavailableView {
                Label("Search Failed", systemImage: "wifi.slash")
            } description: {
                Text(searchErrorMessage)
            } actions: {
                Button("Try Again") {
                    Task { await search() }
                }
            }
            .padding(.top, 20)
        } else if searchResults.isEmpty {
            ContentUnavailableView.search(text: searchQuery)
                .padding(.top, 20)
        } else {
            FoodResultsCardView(title: "Results", items: searchResults) { product in
                NavigationLink {
                    ProductLookupResultView(foodItem: resolveFoodItem(for: product), mealSlot: mealSlot, date: date, onLogged: onLogged)
                } label: {
                    SearchResultRowView(product: product)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func search() async {
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            searchErrorMessage = nil
            isLoadingResults = false
            return
        }

        isLoadingResults = true
        searchErrorMessage = nil

        // Debounce: wait for a pause in typing before hitting the network. `.task(id:)` cancels
        // this task outright as soon as `searchQuery` changes again, so a fast typist never
        // fires more than one request per pause.
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        do {
            searchResults = try await client.searchProducts(query: trimmedQuery, countryName: mealSlot.profile?.resolvedFoodSearchCountryName)
        } catch {
            searchErrorMessage = error.localizedDescription
            searchResults = []
        }
        isLoadingResults = false
    }

    /// Reuses a cached FoodItem for this barcode if one already exists (e.g. from a previous
    /// barcode scan) rather than inserting a duplicate — mirrors `BarcodeScanViewModel`'s
    /// cache-check.
    private func resolveFoodItem(for product: OFFProduct) -> FoodItem {
        guard let barcode = product.code, !barcode.isEmpty else {
            return OpenFoodFactsMapper.makeFoodItem(from: product, barcode: UUID().uuidString)
        }
        let descriptor = FetchDescriptor<FoodItem>(predicate: #Predicate { $0.barcode == barcode })
        if let cached = try? modelContext.fetch(descriptor).first {
            return cached
        }
        let foodItem = OpenFoodFactsMapper.makeFoodItem(from: product, barcode: barcode)
        modelContext.insert(foodItem)
        try? modelContext.save()
        return foodItem
    }
}

/// Small icon-over-caption button for the features the mockup's search pill + barcode button
/// pairing didn't anticipate.
private struct SecondaryActionButton: View {
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.dashboardAccentDeep)
                Text(title)
                    .font(.manrope(10, weight: .semibold))
                    .foregroundStyle(Color.dashboardInkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

/// Uppercase label + a card of divided rows — the mockup's "You log these often" / "All results"
/// treatment, matching the Dashboard's `LoggedMealsCardView` (same index-based divider approach).
private struct FoodResultsCardView<Item, RowContent: View>: View {
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

private struct RecentFoodRowView: View {
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

private struct SearchResultRowView: View {
    let product: OFFProduct

    private var name: String {
        let trimmed = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed?.isEmpty == false) ? trimmed! : "Unknown Product"
    }

    /// Reuses the mapper purely to derive display figures — nothing here is inserted into the
    /// model context, that only happens if this result is actually picked.
    private var preview: FoodItem {
        OpenFoodFactsMapper.makeFoodItem(from: product, barcode: product.code ?? "")
    }

    private var subtitle: String {
        var parts: [String] = []
        if let brand = product.brands?.trimmingCharacters(in: .whitespacesAndNewlines), !brand.isEmpty {
            parts.append(brand)
        }
        let preview = preview
        parts.append("\(Int(preview.caloriesPerServing)) cal")
        parts.append(preview.servingSizeDescription)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            FoodThumbnailView(urlString: product.imageThumbURL, shape: RoundedRectangle(cornerRadius: 11), placeholderColor: .dashboardBarTrack)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
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
