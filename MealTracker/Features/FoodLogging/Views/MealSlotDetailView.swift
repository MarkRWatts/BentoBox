import SwiftUI
import SwiftData

struct MealSlotDetailView: View {
    let mealSlot: MealSlotConfig
    @Query private var entries: [LoggedEntry]
    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingAddFood = false
    @State private var isPresentingBarcodeScan = false

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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.foodItem?.name ?? "Unknown Food")
                        Text("\(entry.quantity, specifier: "%.2f") × \(entry.foodItem?.servingSizeDescription ?? "") — \(Int(entry.calories)) cal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                Menu {
                    Button {
                        isPresentingBarcodeScan = true
                    } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                    }
                    Button {
                        isPresentingAddFood = true
                    } label: {
                        Label("Enter Manually", systemImage: "square.and.pencil")
                    }
                } label: {
                    Label("Add Food", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPresentingAddFood) {
            ManualFoodEntryView(mealSlot: mealSlot)
        }
        .sheet(isPresented: $isPresentingBarcodeScan) {
            BarcodeScanView(mealSlot: mealSlot)
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
        try? modelContext.save()
    }
}
