import SwiftUI

struct OnboardingActivityStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Form {
            Section("Activity Level") {
                Picker("Activity Level", selection: $viewModel.activityLevel) {
                    ForEach(ActivityLevel.allCases) { level in
                        VStack(alignment: .leading) {
                            Text(level.displayName)
                            Text(level.descriptionText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(level)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section {
                OnboardingContinueButton(title: "Next", action: viewModel.goNext)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dashboardCanvas)
    }
}
