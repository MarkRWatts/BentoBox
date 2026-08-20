import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @Query private var profiles: [UserProfile]

    var body: some View {
        if !authManager.isAuthenticated {
            SplashLoginView()
        } else if let profile = profiles.first {
            MainTabView(profile: profile)
        } else {
            OnboardingFlowView()
        }
    }
}
