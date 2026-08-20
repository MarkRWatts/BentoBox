import SwiftUI
import SwiftData

/// Cut-down version of `AddFoodView`'s search — same OFF/USDA-fallback search and "recent foods"
/// list (via the shared `FoodSearchService`/`FoodSearchResult`), but picking a result appends it
/// as a `RecipeIngredient` instead of logging it to a meal.
struct IngredientPickerView: View {
    let recipe: Recipe

    @Query(sort: \FoodItem.lastUsedAt, order: .reverse) private var allFoodItems: [FoodItem]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var searchQuery = ""
    @State private var searchResults: [FoodSearchResult] = []
    @State private var isLoadingResults = false
    @State private var searchErrorMessage: String?
    @FocusState private var isSearchFocused: Bool
    private let searchService = FoodSearchService()

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

                    if trimmedQuery.isEmpty {
                        if !recentItems.isEmpty {
                            FoodResultsCardView(title: "You log these often", items: recentItems) { item in
                                Button {
                                    addIngredient(item)
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
            .navigationTitle("Add Ingredient")
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
            FoodResultsCardView(title: "Results", items: searchResults) { result in
                Button {
                    addIngredient(result.resolveFoodItem(context: modelContext))
                } label: {
                    FoodSearchResultRowView(result: result)
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
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        do {
            searchResults = try await searchService.search(query: trimmedQuery, countryName: recipe.profile?.resolvedFoodSearchCountryName)
        } catch {
            searchErrorMessage = error.localizedDescription
            searchResults = []
        }
        isLoadingResults = false
    }

    private func addIngredient(_ foodItem: FoodItem) {
        let ingredient = RecipeIngredient(quantity: 1, foodItem: foodItem, recipe: recipe)
        modelContext.insert(ingredient)
        try? modelContext.save()
        dismiss()
    }
}
