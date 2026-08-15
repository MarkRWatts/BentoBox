import SwiftUI
import SwiftData

struct LogWeightView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var weightKG: Double

    init(profile: UserProfile) {
        self.profile = profile
        _weightKG = State(initialValue: profile.currentWeightKG ?? 70)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    WeightInputField(unit: profile.weightUnit, weightKG: $weightKG)
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(weightKG <= 0)
                }
            }
        }
    }

    private func save() {
        let entry = BodyMetricEntry(date: Date(), weightKG: weightKG, source: .manual, profile: profile)
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
    }
}
