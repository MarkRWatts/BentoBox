import SwiftUI
import SwiftData

@main
struct MealTrackerApp: App {
    let modelContainer: ModelContainer

    init() {
        modelContainer = ModelContainerFactory.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
