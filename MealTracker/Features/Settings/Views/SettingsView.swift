import SwiftUI
import SwiftData
import PhotosUI

/// Pushed from the Home Screen avatar button (see `DashboardView`'s `.navigationDestination(for:
/// SettingsRoute.self)`), not shown as its own tab — so it deliberately doesn't wrap its own
/// `NavigationStack`; the back button comes from the parent Dashboard stack it's pushed onto.
struct SettingsRoute: Hashable {}

struct SettingsView: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @State private var isPresentingLogWeight = false
    @State private var isPresentingProfileEdit = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSigningIn = false
    @State private var signInError: String?

    var body: some View {
        Form {
            Section("Account") {
                HStack(spacing: 12) {
                    AvatarView(size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        if let name = authManager.displayName {
                            Text(name)
                                .font(.manrope(16, weight: .semibold))
                                .foregroundStyle(Color.dashboardInk)
                        } else if authManager.isLocalOnly {
                            Text("Not Signed In")
                                .font(.manrope(16, weight: .semibold))
                                .foregroundStyle(Color.dashboardInk)
                        }
                        if let email = authManager.email {
                            Text(email)
                                .font(.manrope(13))
                                .foregroundStyle(Color.dashboardInkSecondary)
                        }
                    }
                }
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label {
                        Text("Set Profile Photo")
                    } icon: {
                        SettingsRowIcon(symbol: "camera.fill", color: .accentColor)
                    }
                }
                if authManager.customPhotoData != nil {
                    Button(role: .destructive) {
                        authManager.clearCustomPhoto()
                    } label: {
                        Label {
                            Text("Use Google Photo")
                        } icon: {
                            SettingsRowIcon(symbol: "arrow.uturn.backward", color: .brandCarbs)
                        }
                    }
                }
                if authManager.isLocalOnly {
                    Button {
                        signInWithGoogle()
                    } label: {
                        Label {
                            Text("Sign In with Google")
                        } icon: {
                            SettingsRowIcon(symbol: "person.badge.key.fill", color: .accentColor)
                        }
                    }
                    .disabled(isSigningIn)
                }
                Button(role: .destructive) {
                    authManager.signOut()
                } label: {
                    Label {
                        Text(authManager.isSignedIn ? "Log Out" : "Exit")
                    } icon: {
                        SettingsRowIcon(symbol: "rectangle.portrait.and.arrow.right", color: .red)
                    }
                }
            }

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

            Section {
                Toggle("Adaptive Calorie Target", isOn: $profile.isAdaptiveCalorieTargetEnabled)
                if profile.isAdaptiveCalorieTargetEnabled, let adaptiveTarget = profile.adaptiveCalorieTarget {
                    LabeledContent("Calories", value: "\(Int(adaptiveTarget))")
                    if let updatedAt = profile.adaptiveCalorieTargetUpdatedAt {
                        LabeledContent("Last Updated", value: updatedAt.formatted(date: .abbreviated, time: .omitted))
                    }
                } else {
                    LabeledContent("Calories", value: "\(Int(TDEECalculator.dailyCalorieTarget(for: profile)))")
                }
            } header: {
                Text("Daily Targets")
            } footer: {
                if profile.isAdaptiveCalorieTargetEnabled && profile.adaptiveCalorieTarget == nil {
                    Text("Gathering data — needs at least \(AdaptiveTDEECalculator.minimumDays) days of both logged food and weigh-ins before it kicks in. The calorie target above stays on the standard formula until then.")
                } else {
                    Text("Recalculates your calorie target weekly from your actual weight trend and logged intake, instead of a fixed formula.")
                }
            }

            Section("Food Search") {
                Picker("Country", selection: $profile.foodSearchCountryCode) {
                    Text("Automatic").tag(String?.none)
                    ForEach(CountryOption.all) { option in
                        Text(option.englishName).tag(String?.some(option.code))
                    }
                }
            }

            Section("Data") {
                ShareLink(items: exportURLs) {
                    Label {
                        Text("Export My Data")
                    } icon: {
                        SettingsRowIcon(symbol: "square.and.arrow.up", color: .brandCarbs)
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
                    HydrationEditorView(profile: profile)
                } label: {
                    Label {
                        Text("Water & Fasting")
                    } icon: {
                        SettingsRowIcon(symbol: "drop.fill", color: .brandCarbs)
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    authManager.setCustomPhoto(data)
                }
                selectedPhotoItem = nil
            }
        }
        .sheet(isPresented: $isPresentingLogWeight) {
            LogWeightView(profile: profile)
        }
        .sheet(isPresented: $isPresentingProfileEdit) {
            ProfileEditView(profile: profile)
        }
        .alert("Sign In Failed", isPresented: .constant(signInError != nil), presenting: signInError) { _ in
            Button("OK") { signInError = nil }
        } message: { message in
            Text(message)
        }
    }

    private var exportURLs: [URL] {
        [
            DataExporter.exportMealsCSV(profile: profile),
            DataExporter.exportWeightCSV(profile: profile),
            DataExporter.exportWaterCSV(profile: profile)
        ].compactMap { $0 }
    }

    /// Only reachable from local-only mode, where `lastSignedInGoogleUserID` is still nil (no
    /// Google account has ever been seen on this device), so this can never trigger
    /// `LocalDataStore.wipeAll` — it just attaches a real account to the data already here.
    private func signInWithGoogle() {
        guard !isSigningIn else { return }
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                try await authManager.signInWithGoogle()
            } catch {
                signInError = error.localizedDescription
            }
        }
    }
}
