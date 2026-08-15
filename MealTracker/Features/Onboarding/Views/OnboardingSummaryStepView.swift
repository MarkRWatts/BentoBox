import SwiftUI

struct OnboardingSummaryStepView: View {
    @Bindable var viewModel: OnboardingViewModel
    var onComplete: () -> Void

    var body: some View {
        Form {
            Section("Your Daily Targets") {
                LabeledContent("Estimated BMR", value: viewModel.previewBMR, format: .number.precision(.fractionLength(0)))
                LabeledContent("Maintenance (TDEE)", value: viewModel.previewTDEE, format: .number.precision(.fractionLength(0)))
                LabeledContent("Daily Calorie Target", value: viewModel.previewCalorieTarget, format: .number.precision(.fractionLength(0)))
            }

            Section("Macro Targets") {
                LabeledContent("Protein", value: viewModel.previewMacros.proteinGrams, format: .number.precision(.fractionLength(0)))
                LabeledContent("Carbs", value: viewModel.previewMacros.carbGrams, format: .number.precision(.fractionLength(0)))
                LabeledContent("Fat", value: viewModel.previewMacros.fatGrams, format: .number.precision(.fractionLength(0)))
            }

            Section {
                Toggle("Connect Apple Health", isOn: $viewModel.useHealthKitEnergyAdjustment)
            } footer: {
                Text("Uses your actual activity from Apple Health to adjust your calorie target day to day, instead of a fixed activity level. You can turn this on or off later in Settings.")
            }

            Section {
                Button("Get Started") {
                    onComplete()
                }
                .fontWeight(.semibold)
            }
        }
    }
}
