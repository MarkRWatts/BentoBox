import SwiftUI
import SwiftData

/// Single entry point for adding food to a meal slot: search-by-name, recently-used foods for a
/// fast re-log, plus the ways to add something new. Recency-sorted rather than tracking a
/// separate frequency count — foods you eat often keep getting bumped back to the top every time
/// you log them again, so "Recent" already reads as "Frequent" in practice.
///
/// A literal port of the Claude Design mockup's "Log food" screen (1d): a search pill paired with
/// a barcode-scan button, then card-grouped result lists. The mockup only anticipated barcode
/// scanning as a companion action — label scan, manual entry, copy-from-previous-day and recipes
/// are real features it didn't design for, so those live in a compact secondary-actions row instead.
struct AddFoodView: View {
    /// A binding, not a value: the Dashboard's quick-add starts on a *guessed* slot (see
    /// `MealSlotSuggestion`), and retargeting it here has to reach the barcode/label/manual
    /// routes too, which `FoodLoggingFlowView` launches from the same state.
    @Binding var mealSlot: MealSlotConfig
    /// Slots this sheet may be retargeted to. Empty (the default) hides the chip entirely, which
    /// is what opening from a meal slot's own screen wants.
    var slotOptions: [MealSlotConfig] = []
    var date: Date = Date()
    var onSelectBarcodeScan: () -> Void
    var onSelectLabelScan: () -> Void
    var onSelectManualEntry: () -> Void
    var onSelectCopyFromPreviousDay: () -> Void
    var onSelectRecipes: () -> Void
    var onLogged: () -> Void

    @Query(sort: \FoodItem.lastUsedAt, order: .reverse) private var allFoodItems: [FoodItem]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var searchQuery = ""
    @State private var searchResults: [FoodSearchResult] = []
    @State private var isLoadingResults = false
    @State private var searchErrorMessage: String?
    @State private var path = NavigationPath()
    @FocusState private var isSearchFocused: Bool
    private let searchService = FoodSearchService()

    private var recentItems: [FoodItem] {
        Array(allFoodItems.prefix(20))
    }

    private var trimmedQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 12) {
                    if slotOptions.count > 1 {
                        slotChip
                    }
                    searchRow
                    secondaryActionsRow

                    if trimmedQuery.isEmpty {
                        if !recentItems.isEmpty {
                            FoodResultsCardView(title: "You log these often", items: recentItems) { item in
                                Button {
                                    path.append(item)
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
            .navigationDestination(for: FoodItem.self) { foodItem in
                ProductLookupResultView(foodItem: foodItem, mealSlot: mealSlot, date: date, onLogged: onLogged)
            }
            .task(id: searchQuery) {
                await search()
            }
        }
    }

    /// "Adding to Lunch" — states the guess plainly and makes correcting it one tap, rather than
    /// silently logging into a slot the user never picked.
    private var slotChip: some View {
        Menu {
            ForEach(slotOptions) { option in
                Button {
                    mealSlot = option
                } label: {
                    if option.id == mealSlot.id {
                        Label(option.disambiguatedName(among: slotOptions), systemImage: "checkmark")
                    } else {
                        Text(option.disambiguatedName(among: slotOptions))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("ADDING TO")
                    .font(.manrope(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.dashboardInkSecondary)
                Text(mealSlot.name)
                    .font(.manrope(13, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.dashboardInkSecondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Color.dashboardCard, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Meal slot")
        .accessibilityValue(mealSlot.name)
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
                    .foregroundStyle(Color.dashboardCard)
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
            SecondaryActionButton(symbol: "list.bullet.rectangle", title: "Recipes", action: onSelectRecipes)
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
            FoodResultsCardView(title: "Results", items: searchResults) { result in
                Button {
                    // Resolving here (rather than in an inline `NavigationLink` destination
                    // closure) matters: SwiftUI's closure-based `NavigationLink` evaluates every
                    // row's destination eagerly inside a `ForEach`, so a `NavigationLink` here
                    // would insert a `FoodItem` for every visible search result on every re-render
                    // — this view re-renders on each keystroke via `.task(id: searchQuery)`.
                    path.append(result.resolveFoodItem(context: modelContext))
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

        // Debounce: wait for a pause in typing before hitting the network. `.task(id:)` cancels
        // this task outright as soon as `searchQuery` changes again, so a fast typist never
        // fires more than one request per pause.
        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }

        do {
            searchResults = try await searchService.search(query: trimmedQuery, countryName: mealSlot.profile?.resolvedFoodSearchCountryName)
        } catch {
            searchErrorMessage = error.localizedDescription
            searchResults = []
        }
        isLoadingResults = false
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
