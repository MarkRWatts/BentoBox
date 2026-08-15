import SwiftUI

struct OnboardingBasicsStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Form {
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
