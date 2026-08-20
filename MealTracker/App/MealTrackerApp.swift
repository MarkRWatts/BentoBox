import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct MealTrackerApp: App {
    let modelContainer: ModelContainer
    @State private var authManager = AuthManager()

    init() {
        modelContainer = ModelContainerFactory.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .task {
                    await authManager.restorePreviousSignIn()
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(modelContainer)
    }
}
