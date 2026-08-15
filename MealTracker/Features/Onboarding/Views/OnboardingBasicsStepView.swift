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
