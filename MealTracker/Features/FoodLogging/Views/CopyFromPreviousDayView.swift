import SwiftUI
import SwiftData

/// Lets a user pull entries from any earlier day — across all meal slots, not just this one —
/// into the meal slot/date this was opened from. All of the source day's entries start
/// pre-selected so leaving everything checked copies the whole day, while unchecking down to one
/// item copies just that entry.
struct CopyFromPreviousDayView: View {
    let mealSlot: MealSlotConfig
    let date: Date
    var onCompleted: () -> Void

    @Query(sort: \LoggedEntry.date) private var allEntries: [LoggedEntry]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var sourceDate: Date
    @State private var selectedEntryIDs: Set<UUID> = []

    init(mealSlot: MealSlotConfig, date: Date, onCompleted: @escaping () -> Void) {
        self.mealSlot = mealSlot
        self.date = date
        self.onCompleted = onCompleted
        let defaultSourceDate = Calendar.current.date(byAdding: .day, value: -1, to: date.startOfDay) ?? date.startOfDay
        _sourceDate = State(initialValue: defaultSourceDate)
    }

    /// Source day must be strictly before the day being copied into.
    private var maxSourceDate: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: date.startOfDay) ?? date.startOfDay
    }

    /// Same "query everything, filter in Swift" pattern `DashboardView` uses — a SwiftData
    /// `@Query` predicate can't be mutated after `init` to follow a changing `sourceDate`.
    private var profileEntries: [LoggedEntry] {
        allEntries.filter { $0.mealSlot?.profile?.id == mealSlot.profile?.id }
    }

    private var sourceDayEntries: [LoggedEntry] {
        profileEntries.filter { $0.date >= sourceDate.startOfDay && $0.date < sourceDate.endOfDay }
    }

    private struct EntryGroup: Identifiable {
        let id: String
        let sortOrder: Int
        let entries: [LoggedEntry]
    }

    /// Grouped by the slot name *at log time* (survives a renamed/deleted slot), ordered by the
    /// current slot's sortOrder where that's still resolvable.
    private var groupedEntries: [EntryGroup] {
        Dictionary(grouping: sourceDayEntries) { $0.mealSlotNameSnapshot }
            .map { name, entries in
                EntryGroup(id: name, sortOrder: entries.first?.mealSlot?.sortOrder ?? Int.max, entries: entries)
            }
            .sorted { $0.sortOrder != $1.sortOrder ? $0.sortOrder < $1.sortOrder : $0.id < $1.id }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Copy from", selection: $sourceDate, in: ...maxSourceDate, displayedComponents: .date)
                }

                if sourceDayEntries.isEmpty {
                    ContentUnavailableView(
                        "No Entries",
                        systemImage: "tray",
                        description: Text("Nothing was logged on this day.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(groupedEntries) { group in
                        Section(group.id) {
                            ForEach(group.entries) { entry in
                                entryRow(entry)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Copy from Previous Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Copy (\(selectedEntryIDs.count))") {
                        copySelectedEntries()
                    }
                    .disabled(selectedEntryIDs.isEmpty)
                }
            }
            .onAppear { selectAll() }
            .onChange(of: sourceDate) { _, _ in selectAll() }
        }
    }

    private func entryRow(_ entry: LoggedEntry) -> some View {
        let isSelected = selectedEntryIDs.contains(entry.id)
        return Button {
            toggleSelection(entry)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.foodItem?.name ?? "Unknown Food")
                        .foregroundStyle(.primary)
                    Text("\(entry.quantity, specifier: "%.2f") × \(entry.foodItem?.servingSizeDescription ?? "") — \(Int(entry.calories)) cal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func toggleSelection(_ entry: LoggedEntry) {
        if selectedEntryIDs.contains(entry.id) {
            selectedEntryIDs.remove(entry.id)
        } else {
            selectedEntryIDs.insert(entry.id)
        }
    }

    private func selectAll() {
        selectedEntryIDs = Set(sourceDayEntries.map(\.id))
    }

    private func copySelectedEntries() {
        let entriesToCopy = sourceDayEntries.filter { selectedEntryIDs.contains($0.id) }
        for entry in entriesToCopy {
            // Real "now", not the target `date` — mirrors `ProductLookupResultView.logEntry()` so
            // AddFoodView's "Recent" sort reflects this as a fresh use even when backfilling.
            entry.foodItem?.lastUsedAt = Date()
            let copy = LoggedEntry(
                date: date,
                quantity: entry.quantity,
                mealSlotNameSnapshot: mealSlot.name,
                foodItem: entry.foodItem,
                mealSlot: mealSlot
            )
            modelContext.insert(copy)
        }
        try? modelContext.save()
        onCompleted()
    }
}
