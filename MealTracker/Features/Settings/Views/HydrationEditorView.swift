import SwiftUI
import SwiftData

/// Settings for the two Dashboard cards that aren't about food — water and the fasting timer.
/// Both live behind their own toggle rather than always being on: a tracker showing a fasting
/// clock to someone who doesn't fast is just clutter.
struct HydrationEditorView: View {
    @Bindable var profile: UserProfile

    private var unit: VolumeUnit { profile.volumeUnit }

    /// Hand-built rather than `$profile.volumeUnit`: the profile stores the raw string (see
    /// `UserProfile.volumeUnitRawValue`), so there's no generated binding for the enum itself.
    private var volumeUnitBinding: Binding<VolumeUnit> {
        Binding(get: { profile.volumeUnit }, set: { profile.volumeUnit = $0 })
    }

    var body: some View {
        List {
            Section {
                Toggle("Water Tracking", isOn: $profile.isWaterTrackingEnabled)
            } footer: {
                Text("Shows a water card on the Dashboard — one tap logs a glass.")
            }

            if profile.isWaterTrackingEnabled {
                Section("Water") {
                    Picker("Units", selection: volumeUnitBinding) {
                        ForEach(VolumeUnit.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    Stepper(
                        value: $profile.dailyWaterTargetML,
                        in: 500...6000,
                        step: unit.stepML
                    ) {
                        LabeledContent("Daily Target", value: unit.displayString(fromML: profile.dailyWaterTargetML))
                    }
                    Stepper(
                        value: $profile.waterServingML,
                        in: 100...1000,
                        step: unit.stepML
                    ) {
                        LabeledContent("Glass Size", value: unit.displayString(fromML: profile.waterServingML))
                    }
                }
            }

            Section {
                Toggle("Fasting Timer", isOn: $profile.isFastingTimerEnabled)
            } footer: {
                Text("Shows a fasting card on today's Dashboard. The clock keeps running while the app is closed.")
            }

            if profile.isFastingTimerEnabled {
                Section {
                    Picker("Fasting Window", selection: $profile.fastingGoalHours) {
                        ForEach(FastingTimerCalculator.goalPresetHours, id: \.self) { hours in
                            Text("\(FastingTimerCalculator.goalLabel(hours: hours)) · \(Int(hours))h").tag(hours)
                        }
                    }
                } header: {
                    Text("Fasting")
                } footer: {
                    Text("16:8 means a 16-hour fast and an 8-hour eating window. The timer still runs past the goal — it just marks it as reached.")
                }
            }
        }
        .navigationTitle("Water & Fasting")
        .navigationBarTitleDisplayMode(.inline)
    }
}
