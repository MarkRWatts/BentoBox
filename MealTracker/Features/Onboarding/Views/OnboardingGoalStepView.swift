import SwiftUI

struct OnboardingGoalStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Form {
            Section("Goal") {
                Picker("Goal", selection: $viewModel.goal) {
                    ForEach(WeightGoal.allCases) { goal in
                        Text(goal.displayName).tag(goal)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.goal != .maintain {
                Section("Weekly Rate") {
                    Picker("Weekly Rate", selection: $viewModel.goalRateKgPerWeek) {
                        Text("0.25 kg/week").tag(0.25)
                        Text("0.5 kg/week").tag(0.5)
                        Text("0.75 kg/week").tag(0.75)
                        Text("1.0 kg/week").tag(1.0)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }

            Section {
                OnboardingContinueButton(title: "Next", action: viewModel.goNext)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.dashboardCanvas)
    }
}
