import SwiftUI

struct OnboardingBasicsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Form {
            if HealthKitManager.isHealthDataAvailable {
                Section {
                    Button {
                        Task { await viewModel.importFromHealthKit() }
                    } label: {
                        if viewModel.isImportingFromHealthKit {
                            HStack {
                                ProgressView()
                                Text("Importing from Apple Health…")
                            }
                        } else {
                            Label("Import from Apple Health", systemImage: "heart.fill")
                        }
                    }
                    .disabled(viewModel.isImportingFromHealthKit)
                } footer: {
                    if viewModel.didImportFromHealthKit {
                        Text("Filled in what Apple Health has. Double-check the fields below before continuing.")
                    } else {
                        Text("Prefills your sex, birth date, height, and weight from Apple Health, if available.")
                    }
                }
            }

            Section("About You") {
                Picker("Sex", selection: $viewModel.sex) {
                    ForEach(BiologicalSex.allCases) { sex in
                        Text(sex.displayName).tag(sex)
                    }
                }
                DatePicker("Birth Date", selection: $viewModel.birthDate, displayedComponents: .date)
            }

            Section("Units") {
                Picker("Weight Unit", selection: $viewModel.weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                Picker("Height Unit", selection: $viewModel.heightUnit) {
                    ForEach(HeightUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
            }

            Section("Body Measurements") {
                HeightInputField(unit: viewModel.heightUnit, heightCM: $viewModel.heightCM)
                WeightInputField(unit: viewModel.weightUnit, weightKG: $viewModel.currentWeightKG)
            }

            Section {
                Button("Next") { viewModel.goNext() }
            }
        }
    }
}
