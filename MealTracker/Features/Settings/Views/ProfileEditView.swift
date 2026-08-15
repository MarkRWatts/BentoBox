import SwiftUI
import SwiftData

struct ProfileEditView: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var proteinOverrideEnabled: Bool
    @State private var proteinOverrideValue: Double

    init(profile: UserProfile) {
        self.profile = profile
        _proteinOverrideEnabled = State(initialValue: profile.proteinGramsPerKgOverride != nil)
        _proteinOverrideValue = State(initialValue: profile.proteinGramsPerKgOverride ?? 1.8)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("About You") {
                    Picker("Sex", selection: $profile.sex) {
                        ForEach(BiologicalSex.allCases) { sex in
                            Text(sex.displayName).tag(sex)
                        }
                    }
                    DatePicker("Birth Date", selection: $profile.birthDate, displayedComponents: .date)
                }

                Section("Body Measurements") {
                    HStack {
                        Text("Height (cm)")
                        Spacer()
                        TextField("Height", value: $profile.heightCM, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Activity & Goal") {
                    Picker("Activity Level", selection: $profile.activityLevel) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    Picker("Goal", selection: $profile.goal) {
                        ForEach(WeightGoal.allCases) { goal in
                            Text(goal.displayName).tag(goal)
                        }
                    }
                    if profile.goal != .maintain {
                        HStack {
                            Text("Rate (kg/week)")
                            Spacer()
                            TextField("Rate", value: $profile.goalRateKgPerWeek, format: .number.precision(.fractionLength(1...2)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                Section {
                    Toggle("Custom Protein Target", isOn: $proteinOverrideEnabled)
                    if proteinOverrideEnabled {
                        HStack {
                            Text("Protein (g/kg)")
                            Spacer()
                            TextField("g/kg", value: $proteinOverrideValue, format: .number.precision(.fractionLength(1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } footer: {
                    Text("Defaults to 1.8g per kg of body weight when off.")
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.proteinGramsPerKgOverride = proteinOverrideEnabled ? proteinOverrideValue : nil
                        profile.updatedAt = Date()
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
