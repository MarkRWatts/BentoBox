import Foundation
import SwiftData

enum ModelContainerFactory {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema(MealTrackerSchemaV1.models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: MealTrackerMigrationPlan.self,
                configurations: [configuration]
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
