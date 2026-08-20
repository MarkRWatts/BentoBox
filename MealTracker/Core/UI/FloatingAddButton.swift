import SwiftUI

/// The circular "+" that starts food logging, on both the Dashboard and a meal slot's own screen.
struct FloatingAddButton: View {
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
        }
        // `.dashboardAccentDeep` rather than `.accentColor` — same dark-mode contrast issue
        // noted elsewhere: accentColor brightens in dark mode, which combined with the glass
        // material's translucency left the white "+" too low-contrast to read clearly.
        .glassEffect(.regular.tint(.dashboardAccentDeep).interactive(), in: Circle())
        .padding(20)
        .accessibilityLabel(accessibilityLabel)
    }
}
