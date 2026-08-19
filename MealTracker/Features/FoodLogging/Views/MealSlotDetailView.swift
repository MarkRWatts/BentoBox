import SwiftUI
import SwiftData

private enum FoodLoggingSheet: Identifiable {
    case addFood
    case barcodeScan
    case labelScan
    case manualEntry
    case copyFromPreviousDay

    var id: Self { self }
}

struct MealSlotDetailView: View {
    let mealSlot: MealSlotConfig
    let date: Date
    @Query private var entries: [LoggedEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var activeSheet: FoodLoggingSheet?
    @State private var editingEntry: LoggedEntry?

    init(mealSlot: MealSlotConfig, date: Date) {
        self.mealSlot = mealSlot
        self.date = date
        let slotID = mealSlot.id
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        let predicate = #Predicate<LoggedEntry> { entry in
            entry.mealSlot?.id == slotID && entry.date >= startOfDay && entry.date < endOfDay
        }
        _entries = Query(filter: predicate, sort: \LoggedEntry.date)
    }

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    /// Surfaces which day you're logging into while backfilling a past/future day, so it's
    /// clear this isn't logging against real "now".
    private var navigationTitleText: String {
        Calendar.current.isDateInToday(date)
            ? mealSlot.name
            : "\(mealSlot.name) · \(date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    var body: some View {
        List {
            Section {
                if entries.isEmpty {
                    Text("No food logged yet.")
                        .font(.manrope(14, weight: .medium))
                        .foregroundStyle(Color.dashboardInkSecondary)
                }
                ForEach(entries) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        HStack(spacing: 12) {
                            FoodThumbnailView(
                                urlString: entry.foodItem?.imageURLString,
                                shape: RoundedRectangle(cornerRadius: 12),
                                placeholderColor: .dashboardBarTrack,
                                size: 40
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.foodItem?.name ?? "Unknown Food")
                                    .font(.manrope(14, weight: .semibold))
                                    .foregroundStyle(Color.dashboardInk)
                                Text("\(entry.quantity, specifier: "%.2f") × \(entry.foodItem?.servingSizeDescription ?? "") — \(Int(entry.calories)) cal")
                                    .font(.manrope(11.5, weight: .medium))
                                    .foregroundStyle(Color.dashboardInkSecondary)
                            }
                        }
                    }
                    .listRowBackground(Color.dashboardCard)
                }
                .onDelete(perform: deleteEntries)
            } header: {
                Text("\(Int(totalCalories)) CALORIES LOGGED")
                    .font(.manrope(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.dashboardAccent)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dashboardCanvas)
        .navigationTitle(navigationTitleText)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            addFoodButton
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addFood:
                AddFoodView(
                    mealSlot: mealSlot,
                    date: date,
                    onSelectBarcodeScan: { activeSheet = .barcodeScan },
                    onSelectLabelScan: { activeSheet = .labelScan },
                    onSelectManualEntry: { activeSheet = .manualEntry },
                    onSelectCopyFromPreviousDay: { activeSheet = .copyFromPreviousDay },
                    onLogged: { activeSheet = nil }
                )
            case .barcodeScan:
                BarcodeScanView(mealSlot: mealSlot, date: date)
            case .labelScan:
                LabelScanView(mealSlot: mealSlot, date: date)
            case .manualEntry:
                ManualFoodEntryView(mealSlot: mealSlot, date: date)
            case .copyFromPreviousDay:
                CopyFromPreviousDayView(mealSlot: mealSlot, date: date, onCompleted: { activeSheet = nil })
            }
        }
        .sheet(item: $editingEntry) { entry in
            EditLoggedEntryView(entry: entry)
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
        try? modelContext.save()
    }

    private var addFoodButton: some View {
        Button {
            activeSheet = .addFood
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
        }
        // `.dashboardAccentDeep` rather than `.accentColor` — same dark-mode contrast issue
        // noted elsewhere: accentColor brightens in dark mode, which combined with the glass
        // material's translucency left the white "+" too low-contrast to read clearly.
        .glassEffect(.regular.tint(.dashboardAccentDeep).interactive(), in: Circle())
        .padding(20)
        .accessibilityLabel("Add Food")
    }
}
