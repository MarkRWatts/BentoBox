import SwiftUI
import SwiftData

/// Single entry point for adding food to a meal slot: search-by-name, recently-used foods for a
/// fast re-log, plus the three ways to add something new. Recency-sorted rather than tracking a
/// separate frequency count — foods you eat often keep getting bumped back to the top every time
/// you log them again, so "Recent" already reads as "Frequent" in practice.
struct AddFoodView: View {
    let mealSlot: MealSlotConfig
    var date: Date = Date()
    var onSelectBarcodeScan: () -> Void
    var onSelectLabelScan: () -> Void
    var onSelectManualEntry: () -> Void
    var onLogged: () -> Void

    @Query(sort: \FoodItem.lastUsedAt, order: .reverse) private var allFoodItems: [FoodItem]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var searchQuery = ""
    @State private var searchResults: [OFFProduct] = []
    @State private var isLoadingResults = false
    @State private var searchErrorMessage: String?
    private let client = OpenFoodFactsClient()

    private var recentItems: [FoodItem] {
        Array(allFoodItems.prefix(20))
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    Section {
                        Button(action: onSelectBarcodeScan) {
                            Label("Scan Barcode", systemImage: "barcode.viewfinder")
                        }
                        Button(action: onSelectLabelScan) {
                            Label("Scan Nutrition Label", systemImage: "text.viewfinder")
                        }
                        Button(action: onSelectManualEntry) {
                            Label("Enter Manually", systemImage: "square.and.pencil")
                        }
                    }

                    if !recentItems.isEmpty {
                        Section("Recent") {
                            ForEach(recentItems) { item in
                                NavigationLink {
                                    ProductLookupResultView(foodItem: item, mealSlot: mealSlot, date: date, onLogged: onLogged)
                                } label: {
                                    RecentFoodRowView(foodItem: item)
                                }
                            }
                        }
                    }
                } else {
                    searchResultsContent
                }
            }
            .searchable(text: $searchQuery, prompt: "Search foods")
            .navigationTitle("Add Food")
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

    @ViewBuilder
    private var searchResultsContent: some View {
        if isLoadingResults {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .listRowBackground(Color.clear)
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
            .listRowBackground(Color.clear)
        } else if searchResults.isEmpty {
            ContentUnavailableView.search(text: searchQuery)
                .listRowBackground(Color.clear)
        } else {
            Section("Results") {
                ForEach(searchResults, id: \.code) { product in
                    NavigationLink {
                        ProductLookupResultView(foodItem: resolveFoodItem(for: product), mealSlot: mealSlot, date: date, onLogged: onLogged)
                    } label: {
                        SearchResultRowView(product: product)
                    }
                }
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
            searchResults = try await client.searchProducts(query: trimmedQuery)
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

private struct RecentFoodRowView: View {
    let foodItem: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(foodItem.name)
            Text("\(Int(foodItem.caloriesPerServing)) cal · \(foodItem.servingSizeDescription)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
