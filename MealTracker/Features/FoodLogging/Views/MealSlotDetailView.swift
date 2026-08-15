import SwiftUI
import SwiftData

private enum FoodLoggingSheet: Identifiable {
    case addFood
    case barcodeScan
    case labelScan
    case manualEntry

    var id: Self { self }
}

struct MealSlotDetailView: View {
    let mealSlot: MealSlotConfig
    @Query private var entries: [LoggedEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var activeSheet: FoodLoggingSheet?
    @State private var editingEntry: LoggedEntry?

    init(mealSlot: MealSlotConfig) {
        self.mealSlot = mealSlot
        let slotID = mealSlot.id
        let startOfDay = Date().startOfDay
        let endOfDay = Date().endOfDay
        let predicate = #Predicate<LoggedEntry> { entry in
            entry.mealSlot?.id == slotID && entry.date >= startOfDay && entry.date < endOfDay
        }
        _entries = Query(filter: predicate, sort: \LoggedEntry.date)
    }

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        List {
            Section {
                if entries.isEmpty {
                    Text("No food logged yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    Button {
                        editingEntry = entry
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.foodItem?.name ?? "Unknown Food")
                                .foregroundStyle(.primary)
                            Text("\(entry.quantity, specifier: "%.2f") × \(entry.foodItem?.servingSizeDescription ?? "") — \(Int(entry.calories)) cal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteEntries)
            } header: {
                Text("\(Int(totalCalories)) calories logged")
            }
        }
        .navigationTitle(mealSlot.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    activeSheet = .addFood
                } label: {
                    Label("Add Food", systemImage: "plus")
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addFood:
                AddFoodView(
                    mealSlot: mealSlot,
                    onSelectBarcodeScan: { activeSheet = .barcodeScan },
                    onSelectLabelScan: { activeSheet = .labelScan },
                    onSelectManualEntry: { activeSheet = .manualEntry },
                    onLogged: { activeSheet = nil }
                )
            case .barcodeScan:
                BarcodeScanView(mealSlot: mealSlot)
            case .labelScan:
                LabelScanView(mealSlot: mealSlot)
            case .manualEntry:
                ManualFoodEntryView(mealSlot: mealSlot)
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
}
