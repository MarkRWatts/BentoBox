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

            Section("Body Measurements") {
                HStack {
                    Text("Height (cm)")
                    Spacer()
                    TextField("Height", value: $viewModel.heightCM, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Weight (kg)")
                    Spacer()
                    TextField("Weight", value: $viewModel.currentWeightKG, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                Button("Next") { viewModel.goNext() }
            }
        }
    }
}
