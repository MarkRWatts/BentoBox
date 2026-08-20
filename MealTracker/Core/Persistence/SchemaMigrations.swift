import SwiftData

enum MealTrackerSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            UserProfile.self, BodyMetricEntry.self, MealSlotConfig.self, FoodItem.self, LoggedEntry.self,
            DayCalorieOverride.self, Recipe.self, RecipeIngredient.self
        ]
    }
}

enum MealTrackerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [MealTrackerSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
