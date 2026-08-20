import SwiftData

/// Resets every on-device model to empty — used when a different Google account signs in than
/// last time (see `AuthManager.signInWithGoogle`), so the app treats it as a fresh user rather
/// than showing one account's meal history to another. Deletes every model type explicitly
/// rather than relying on `UserProfile`'s cascade rules: `MealSlotConfig` → `LoggedEntry` is a
/// `.nullify` relationship by design (deleting a meal slot shouldn't erase history), and
/// `LoggedEntry`/`FoodItem` aren't reachable from `UserProfile` at all, so a cascade-only delete
/// would silently orphan rows instead of clearing them. `Recipe` cascades to `RecipeIngredient`,
/// but that's deleted explicitly too rather than leaned on, for the same reason.
enum LocalDataStore {
    static func wipeAll(context: ModelContext) {
        // Listed explicitly (not looped over `MealTrackerSchemaV1.models`) since
        // `ModelContext.delete(model:)` is generic over a concrete `PersistentModel` type, not
        // the `any PersistentModel.Type` existentials that array holds.
        try? context.delete(model: LoggedEntry.self)
        try? context.delete(model: RecipeIngredient.self)
        try? context.delete(model: Recipe.self)
        try? context.delete(model: FoodItem.self)
        try? context.delete(model: MealSlotConfig.self)
        try? context.delete(model: BodyMetricEntry.self)
        try? context.delete(model: WaterLogEntry.self)
        try? context.delete(model: DayCalorieOverride.self)
        try? context.delete(model: UserProfile.self)
        try? context.save()
    }
}
