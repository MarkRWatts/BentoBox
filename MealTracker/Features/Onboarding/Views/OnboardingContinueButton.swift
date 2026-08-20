import SwiftUI

/// The Claude Design mockup's dark rounded "Continue" pill (1f), reused across every onboarding
/// step's final `Form` section in place of the default plain button row.
struct OnboardingContinueButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.manrope(14.5, weight: .bold))
                .foregroundStyle(Color.dashboardCard)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.dashboardInk, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.vertical, 4)
    }
}
