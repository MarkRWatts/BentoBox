import SwiftUI
import SwiftData

/// Shown whenever `AuthManager.isAuthenticated` is false. Reuses the same `LaunchSplash` artwork as
/// the static OS launch screen (`LaunchScreen.storyboard`) as a full-bleed background — rather
/// than importing a second flat "login" image — so the call-to-action stays a real SwiftUI
/// button (Dynamic Type, VoiceOver, dark mode) instead of being baked into a bitmap.
struct SplashLoginView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.modelContext) private var modelContext
    @State private var isSigningIn = false
    @State private var signInError: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("LaunchSplash")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Button {
                    signIn()
                } label: {
                    HStack {
                        Text("Get Started")
                        Spacer()
                        if isSigningIn {
                            ProgressView()
                                .tint(Color.dashboardCard)
                        } else {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(.manrope(17, weight: .bold))
                    .foregroundStyle(Color.dashboardCard)
                    .padding(.horizontal, 24)
                    .frame(height: 56)
                    .background(Color.dashboardAccent, in: Capsule())
                }
                .disabled(isSigningIn)

                Button {
                    signIn()
                } label: {
                    (Text("Already have an account? ") + Text("Sign In").foregroundStyle(Color.dashboardAccent))
                        .font(.manrope(14, weight: .medium))
                        .foregroundStyle(Color.dashboardInkSecondary)
                }
                .disabled(isSigningIn)

                // Nothing here actually requires an account — everything's on-device with no
                // backend — so this is a real option, not just a Simulator workaround (Google
                // sign-in needs a passkey-capable session, which the Simulator can't do).
                Button {
                    authManager.continueWithoutAccount()
                } label: {
                    Text("Continue without an account")
                        .font(.manrope(13, weight: .medium))
                        .foregroundStyle(Color.dashboardInkSecondary)
                        .underline()
                }
                .disabled(isSigningIn)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .alert("Sign In Failed", isPresented: .constant(signInError != nil), presenting: signInError) { _ in
            Button("OK") { signInError = nil }
        } message: { message in
            Text(message)
        }
    }

    private func signIn() {
        guard !isSigningIn else { return }
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                let didSwitchAccount = try await authManager.signInWithGoogle()
                if didSwitchAccount {
                    LocalDataStore.wipeAll(context: modelContext)
                }
            } catch {
                signInError = error.localizedDescription
            }
        }
    }
}
