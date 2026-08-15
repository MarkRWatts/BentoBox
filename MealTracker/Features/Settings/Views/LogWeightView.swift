import SwiftUI
import SwiftData

struct LogWeightView: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var weightKG: Double
    @State private var healthKit = HealthKitManager.shared

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
                        Task { await save() }
                    }
                    .disabled(weightKG <= 0)
                }
            }
        }
    }

    private func save() async {
        let date = Date()
        let entry = BodyMetricEntry(date: date, weightKG: weightKG, source: .manual, profile: profile)
        modelContext.insert(entry)
        try? modelContext.save()
        await healthKit.saveBodyMass(kg: weightKG, date: date)
        dismiss()
    }
}
