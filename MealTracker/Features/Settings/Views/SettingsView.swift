import SwiftUI
import SwiftData

struct SettingsView: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @State private var isPresentingLogWeight = false
    @State private var isPresentingProfileEdit = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Settings")
                        .font(.archivo(30, weight: .semibold))
                        .foregroundStyle(Color.dashboardInk)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 4, trailing: 20))
                .listRowSeparator(.hidden)

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

                Section("Food Search") {
                    Picker("Country", selection: $profile.foodSearchCountryCode) {
                        Text("Automatic").tag(String?.none)
                        ForEach(CountryOption.all) { option in
                            Text(option.englishName).tag(String?.some(option.code))
                        }
                    }
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
            }
            .contentMargins(.top, 0, for: .scrollContent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isPresentingLogWeight) {
                LogWeightView(profile: profile)
            }
            .sheet(isPresented: $isPresentingProfileEdit) {
                ProfileEditView(profile: profile)
            }
        }
    }
}
