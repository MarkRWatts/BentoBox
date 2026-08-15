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
                    LabeledContent("Height", value: profile.heightUnit.displayString(fromCM: profile.heightCM))
                    if let weight = profile.currentWeightKG {
                        LabeledContent("Weight", value: profile.weightUnit.displayString(fromKG: weight))
                    }
                    LabeledContent("Activity Level", value: profile.activityLevel.displayName)
                    LabeledContent("Goal", value: profile.goal.displayName)
                    Button {
                        isPresentingLogWeight = true
                    } label: {
                        Label {
                            Text("Log Weight")
                        } icon: {
                            SettingsRowIcon(symbol: "scalemass.fill", color: .brandCarbs)
                        }
                    }
                    Button {
                        isPresentingProfileEdit = true
                    } label: {
                        Label {
                            Text("Edit Profile")
                        } icon: {
                            SettingsRowIcon(symbol: "person.fill", color: .accentColor)
                        }
                    }
                }

                Section("Daily Targets") {
                    LabeledContent("Calories", value: "\(Int(TDEECalculator.dailyCalorieTarget(for: profile)))")
                }

                Section {
                    NavigationLink {
                        MealSlotEditorView(profile: profile)
                    } label: {
                        Label {
                            Text("Meal Slots")
                        } icon: {
                            SettingsRowIcon(symbol: "fork.knife", color: .brandProtein)
                        }
                    }
                    NavigationLink {
                        CalorieCyclingEditorView(profile: profile)
                    } label: {
                        Label {
                            Text("Calorie Cycling")
                        } icon: {
                            SettingsRowIcon(symbol: "arrow.triangle.2.circlepath", color: .orange)
                        }
                    }
                }

                Section {
                    Toggle(isOn: $profile.useHealthKitEnergyAdjustment) {
                        Label {
                            Text("Adjust Target Using Apple Health")
                        } icon: {
                            SettingsRowIcon(symbol: "heart.fill", color: .pink)
                        }
                    }
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
