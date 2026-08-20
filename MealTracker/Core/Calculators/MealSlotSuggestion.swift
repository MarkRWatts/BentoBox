import Foundation

/// Picks which meal slot a quick-add from the Dashboard should default to, so logging can start
/// from "what did I eat" instead of "which slot am I in" — see `DashboardView`'s add button.
///
/// Slots carry no times of their own (`MealSlotConfig` is a name plus a sort order), and adding
/// per-slot times would mean a schema change and a settings screen for something the ordering
/// already implies. So the eating day is split evenly across the enabled *meal* slots in their
/// configured order: with the default Breakfast/Lunch/Dinner that lands at roughly 06:00–11:20,
/// 11:20–16:40, 16:40–22:00. Snack slots are deliberately skipped — a snack is a deliberate
/// choice, never a good guess — but stay one tap away behind the sheet's slot chip.
enum MealSlotSuggestion {
    /// The window the split covers. Outside it (late night, small hours) the last meal of the day
    /// is the better guess than wrapping back around to breakfast.
    static let dayStartHour = 6.0
    static let dayEndHour = 22.0

    static func suggestedSlot(
        at date: Date,
        from slots: [MealSlotConfig],
        calendar: Calendar = .current
    ) -> MealSlotConfig? {
        let enabled = slots.filter(\.isEnabled).sorted { $0.sortOrder < $1.sortOrder }
        let meals = enabled.filter { $0.slotType == .meal }
        // A profile that has turned every meal slot off still gets a sensible target rather than
        // a disabled button.
        guard !meals.isEmpty else { return enabled.first }

        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60

        guard hour >= dayStartHour else { return meals[meals.count - 1] }
        guard hour < dayEndHour else { return meals[meals.count - 1] }

        let windowLength = (dayEndHour - dayStartHour) / Double(meals.count)
        let index = Int((hour - dayStartHour) / windowLength)
        return meals[min(index, meals.count - 1)]
    }
}
