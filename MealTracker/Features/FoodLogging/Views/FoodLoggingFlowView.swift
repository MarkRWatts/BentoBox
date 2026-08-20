import SwiftUI
import SwiftData

/// Everything behind the "+": search and recents, plus the barcode/label/manual/copy/recipe
/// routes out of them. Owns which of those is on screen so a caller only ever presents this one
/// sheet — the alternative (each caller keeping its own `activeSheet` enum) meant duplicating the
/// same switch in every place food can be logged from, which is now the Dashboard as well as a
/// meal slot's own screen.
///
/// Stages replace each other inside the sheet rather than stacking as nested sheets, matching how
/// the flow behaved when the cases were separate `.sheet(item:)` presentations: dismissing from
/// anywhere closes the whole thing.
struct FoodLoggingFlowView: View {
    let initialSlot: MealSlotConfig
    /// The day being logged into. Times are stamped `atCurrentTimeOfDay` on the way into each
    /// stage, so backfilling a past day still records a plausible clock time rather than midnight.
    let date: Date
    /// The slots this sheet may be retargeted to. Empty from a meal slot's own screen, where the
    /// slot is the context you're already standing in; the Dashboard passes every enabled slot,
    /// since its starting slot is a guess (see `MealSlotSuggestion`).
    var slotOptions: [MealSlotConfig] = []

    @Environment(\.dismiss) private var dismiss
    @State private var stage: Stage = .addFood
    @State private var mealSlot: MealSlotConfig

    init(initialSlot: MealSlotConfig, date: Date, slotOptions: [MealSlotConfig] = []) {
        self.initialSlot = initialSlot
        self.date = date
        self.slotOptions = slotOptions
        _mealSlot = State(initialValue: initialSlot)
    }

    private enum Stage {
        case addFood
        case barcodeScan
        case labelScan
        case manualEntry
        case copyFromPreviousDay
        case recipes
    }

    var body: some View {
        switch stage {
        case .addFood:
            AddFoodView(
                mealSlot: $mealSlot,
                slotOptions: slotOptions,
                date: date.atCurrentTimeOfDay,
                onSelectBarcodeScan: { stage = .barcodeScan },
                onSelectLabelScan: { stage = .labelScan },
                onSelectManualEntry: { stage = .manualEntry },
                onSelectCopyFromPreviousDay: { stage = .copyFromPreviousDay },
                onSelectRecipes: { stage = .recipes },
                onLogged: { dismiss() }
            )
        case .barcodeScan:
            BarcodeScanView(mealSlot: mealSlot, date: date.atCurrentTimeOfDay)
        case .labelScan:
            LabelScanView(mealSlot: mealSlot, date: date.atCurrentTimeOfDay)
        case .manualEntry:
            ManualFoodEntryView(mealSlot: mealSlot, date: date.atCurrentTimeOfDay)
        case .copyFromPreviousDay:
            CopyFromPreviousDayView(mealSlot: mealSlot, date: date, onCompleted: { dismiss() })
        case .recipes:
            RecipeListView(mealSlot: mealSlot, date: date.atCurrentTimeOfDay, onLogged: { dismiss() })
        }
    }
}
