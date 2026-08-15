import SwiftUI

struct SettingsView: View {
    let profile: UserProfile

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    LabeledContent("Sex", value: profile.sex.displayName)
                    LabeledContent("Age", value: "\(profile.ageYears)")
                    LabeledContent("Height", value: "\(Int(profile.heightCM)) cm")
                    if let weight = profile.currentWeightKG {
                        LabeledContent("Weight", value: String(format: "%.1f kg", weight))
                    }
                    LabeledContent("Activity Level", value: profile.activityLevel.displayName)
                    LabeledContent("Goal", value: profile.goal.displayName)
                }

                Section("Daily Targets") {
                    LabeledContent("Calories", value: "\(Int(TDEECalculator.dailyCalorieTarget(for: profile)))")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
