import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: Double(viewModel.step.rawValue + 1), total: Double(OnboardingViewModel.Step.allCases.count))
                    .padding(.horizontal)
                    .padding(.top, 8)

                Group {
                    switch viewModel.step {
                    case .basics:
                        OnboardingBasicsStepView(viewModel: viewModel)
                    case .activity:
                        OnboardingActivityStepView(viewModel: viewModel)
                    case .goal:
                        OnboardingGoalStepView(viewModel: viewModel)
                    case .summary:
                        OnboardingSummaryStepView(viewModel: viewModel) {
                            Task { await viewModel.completeOnboarding(context: modelContext) }
                        }
                    }
                }
            }
            .navigationTitle("Set Up Bento Box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.step != .basics {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back") { viewModel.goBack() }
                    }
                }
            }
        }
    }
}
