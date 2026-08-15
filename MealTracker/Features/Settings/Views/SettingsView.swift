import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @State private var healthKit = HealthKitManager.shared
    @State private var isPresentingLogWeight = false
    @State private var isPresentingProfileEdit = false

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
                    Button("Log Weight") {
                        isPresentingLogWeight = true
                    }
                    Button("Edit Profile") {
                        isPresentingProfileEdit = true
                    }
                }

                Section("Daily Targets") {
                    LabeledContent("Calories", value: "\(Int(TDEECalculator.dailyCalorieTarget(for: profile)))")
                }

                Section {
                    NavigationLink("Meal Slots") {
                        MealSlotEditorView(profile: profile)
                    }
                    NavigationLink("Calorie Cycling") {
                        CalorieCyclingEditorView(profile: profile)
                    }
                }

                Section {
                    Toggle("Adjust Target Using Apple Health", isOn: $profile.useHealthKitEnergyAdjustment)
                        .onChange(of: profile.useHealthKitEnergyAdjustment) { _, isOn in
                            if isOn { Task { await healthKit.requestAuthorization() } }
                        }
                } header: {
                    Text("Apple Health")
                } footer: {
                    if HealthKitManager.isHealthDataAvailable {
                        Text("Uses today's actual activity from Apple Health instead of a fixed activity level, and syncs your logged food and weight to the Health app.")
                    } else {
                        Text("Apple Health isn't available on this device.")
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isPresentingLogWeight) {
                LogWeightView(profile: profile)
            }
            .sheet(isPresented: $isPresentingProfileEdit) {
                ProfileEditView(profile: profile)
            }
            .task {
                await reconcileWeightFromHealthKit()
            }
        }
    }

    /// One-way pull: if HealthKit has a body-mass sample newer than our latest local entry (e.g.
    /// logged via a smart scale or the Health app directly), mirror it in so the dashboard/weight
    /// trend reflect it without the user re-entering it by hand.
    private func reconcileWeightFromHealthKit() async {
        guard healthKit.isAuthorized, let latest = await healthKit.latestBodyMass() else { return }
        if let localLatestDate = profile.weightHistory.map(\.date).max(), localLatestDate >= latest.date {
            return
        }
        let entry = BodyMetricEntry(date: latest.date, weightKG: latest.weightKG, source: .healthKit, profile: profile)
        modelContext.insert(entry)
        try? modelContext.save()
    }
}
