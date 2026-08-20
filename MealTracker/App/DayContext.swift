import Foundation
import Observation

/// The day the Today and Log tabs are both looking at.
///
/// Deliberately a reference type rather than `@State` + `@Binding` on `MainTabView`: the week
/// strip writes the selected day back as it settles, and with the date held as tab-view state
/// every such write invalidated all three tabs at once. That re-layout landed mid-scroll on the
/// strip's 1,461-column `LazyHStack` and left it rendering a stale window — the strip came up
/// un-centered, showing the wrong day under its caret. Observation tracks property reads, so
/// passing this object down means only the views that actually read `selectedDate` re-render.
@Observable
final class DayContext {
    var selectedDate: Date = Date().startOfDay
}
