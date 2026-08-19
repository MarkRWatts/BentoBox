import SwiftUI

/// Chronological alternative to `MealSlotGroupedListView`, ported from the Claude Design
/// "Timeline-first" mockup direction (#1c): a proportional budget rail plus a vertical thread of
/// dots, one per logged entry, instead of grouping by meal slot. `entries` must already be sorted
/// oldest-to-newest.
struct EntryTimelineView: View {
    let entries: [LoggedEntry]
    let calorieTarget: Double
    let isToday: Bool
    let onSelectEntry: (LoggedEntry) -> Void

    /// Cycles the same three brand greens the mockup uses for both the budget-rail segments and
    /// their matching dot on the thread below, so a segment's color always identifies its entry.
    private static let dotColors: [Color] = [.dashboardAccentDeep, .dashboardAccent, .dashboardCarbFill]

    private func color(for index: Int) -> Color {
        Self.dotColors[index % Self.dotColors.count]
    }

    private var totalCalories: Double {
        entries.reduce(0) { $0 + $1.calories }
    }

    private var remaining: Double {
        calorieTarget - totalCalories
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if entries.isEmpty {
                Text("No food logged yet.")
                    .font(.manrope(14, weight: .medium))
                    .foregroundStyle(Color.dashboardInkSecondary)
            } else {
                budgetRail
                captionLine
                thread
            }
        }
    }

    private var budgetRail: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Capsule()
                        .fill(color(for: index))
                        .frame(width: max(3, geometry.size.width * CGFloat(entry.calories / max(calorieTarget, 1))))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: 6)
        .background(Color.dashboardBarTrack, in: Capsule())
        .clipShape(Capsule())
    }

    private var captionLine: some View {
        HStack {
            Text(entries.count == 1 ? "1 entry" : "\(entries.count) entries")
                .font(.manrope(11, weight: .medium))
                .foregroundStyle(Color.dashboardInkFaint)
            Spacer()
            Text(remaining >= 0 ? "\(Int(remaining)) left" : "\(Int(-remaining)) over")
                .font(.manrope(11, weight: .semibold))
                .foregroundStyle(remaining >= 0 ? Color.dashboardAccent : Color.brandProtein)
        }
    }

    private var thread: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Button {
                    onSelectEntry(entry)
                } label: {
                    TimelineEntryRowView(entry: entry, dotColor: color(for: index))
                }
                .buttonStyle(.plain)
            }
            if isToday {
                TimelineNowRowView(lastEntryDate: entries.last?.date)
            }
        }
        .background(alignment: .topLeading) {
            Rectangle()
                .fill(Color.dashboardDivider)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 5)
                .padding(.leading, TimelineLayout.railCenterX)
        }
    }
}

/// Shared column widths so every row's dot lands at the same x — and so the rail line drawn
/// behind the thread in `EntryTimelineView` lines up with it.
private enum TimelineLayout {
    static let timeColumnWidth: CGFloat = 38
    static let railColumnWidth: CGFloat = 16
    static let rowSpacing: CGFloat = 12
    static let railCenterX: CGFloat = timeColumnWidth + rowSpacing + railColumnWidth / 2
}

private struct TimelineEntryRowView: View {
    let entry: LoggedEntry
    let dotColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: TimelineLayout.rowSpacing) {
            Text(entry.date.formatted(.dateTime.hour().minute()))
                .font(.manrope(11, weight: .medium))
                .foregroundStyle(Color.dashboardInkSecondary)
                .frame(width: TimelineLayout.timeColumnWidth, alignment: .trailing)
                .padding(.top, 2)

            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .overlay(Circle().strokeBorder(Color.dashboardCard, lineWidth: 2))
                .frame(width: TimelineLayout.railColumnWidth)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.foodItem?.name ?? "Unknown Food")
                    .font(.manrope(14.5, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Text("\(Int(entry.calories)) kcal · \(Int(entry.proteinGrams)) g protein")
                    .font(.manrope(11.5, weight: .medium))
                    .foregroundStyle(Color.dashboardInkSecondary)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Trailing dashed node marking "now" — only shown when viewing today, since a past day has no
/// live "time since" to report.
private struct TimelineNowRowView: View {
    let lastEntryDate: Date?

    private var text: String {
        guard let lastEntryDate else { return "Nothing logged today yet." }
        return "Nothing since \(lastEntryDate.formatted(.dateTime.hour().minute()))."
    }

    var body: some View {
        HStack(alignment: .top, spacing: TimelineLayout.rowSpacing) {
            Text("now")
                .font(.manrope(11, weight: .medium))
                .foregroundStyle(Color.dashboardInkFaint)
                .frame(width: TimelineLayout.timeColumnWidth, alignment: .trailing)
                .padding(.top, 2)

            Circle()
                .fill(Color.dashboardCard)
                .overlay(Circle().strokeBorder(Color.dashboardInkFaint, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2])))
                .frame(width: 10, height: 10)
                .frame(width: TimelineLayout.railColumnWidth)
                .padding(.top, 3)

            Text(text)
                .font(.manrope(13, weight: .medium))
                .foregroundStyle(Color.dashboardInkSecondary)
        }
    }
}
