import SwiftUI
import SwiftData

struct MealSlotEditorView: View {
    let profile: UserProfile

    @Query(sort: \MealSlotConfig.sortOrder) private var allSlots: [MealSlotConfig]
    @Environment(\.modelContext) private var modelContext
    @State private var isAddingSlot = false

    private var slots: [MealSlotConfig] {
        allSlots.filter { $0.profile?.id == profile.id }
    }

    var body: some View {
        List {
            Section {
                ForEach(slots) { slot in
                    MealSlotRowEditView(slot: slot)
                }
                .onDelete(perform: deleteSlots)
                .onMove(perform: moveSlots)
            } footer: {
                Text("Drag to reorder. Turning a slot off hides it from Today without deleting its history.")
            }
        }
        .navigationTitle("Meal Slots")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingSlot = true
                } label: {
                    Label("Add Slot", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingSlot) {
            AddMealSlotView(profile: profile, nextSortOrder: (slots.map(\.sortOrder).max() ?? -1) + 1)
        }
    }

    private func deleteSlots(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(slots[index])
        }
        try? modelContext.save()
    }

    private func moveSlots(from source: IndexSet, to destination: Int) {
        var reordered = slots
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, slot) in reordered.enumerated() {
            slot.sortOrder = index
        }
        try? modelContext.save()
    }
}

private struct MealSlotRowEditView: View {
    @Bindable var slot: MealSlotConfig

    var body: some View {
        HStack {
            TextField("Name", text: $slot.name)
            Spacer()
            Text(slot.slotType == .meal ? "Meal" : "Snack")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Enabled", isOn: $slot.isEnabled)
                .labelsHidden()
        }
    }
}

private struct AddMealSlotView: View {
    let profile: UserProfile
    let nextSortOrder: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var slotType: MealSlotType = .snack

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $slotType) {
                    Text("Meal").tag(MealSlotType.meal)
                    Text("Snack").tag(MealSlotType.snack)
                }
            }
            .navigationTitle("New Slot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let slot = MealSlotConfig(name: name.trimmingCharacters(in: .whitespaces), slotType: slotType, sortOrder: nextSortOrder, profile: profile)
                        modelContext.insert(slot)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
