import SwiftUI

/// Apple Fitness-style month grid: a dot per day (filled when that day has logged entries),
/// month-to-month navigation, tap a day to jump the Dashboard there. Monday-first (hardcoded,
/// matching `WeekStripView`) and adapts to system light/dark rather than forcing dark chrome,
/// unlike Apple's own app.
struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    let profile: UserProfile
    let daysWithEntries: Set<Date>
    /// Start-of-day keys for the (necessarily also `daysWithEntries`) days whose calories ended
    /// up over target — see `DashboardView.daysOverTarget(from:)`.
    let daysOverTarget: Set<Date>

    @Environment(\.dismiss) private var dismiss
    @State private var displayedMonth: Date

    init(selectedDate: Binding<Date>, profile: UserProfile, daysWithEntries: Set<Date>, daysOverTarget: Set<Date>) {
        self._selectedDate = selectedDate
        self.profile = profile
        self.daysWithEntries = daysWithEntries
        self.daysOverTarget = daysOverTarget
        self._displayedMonth = State(initialValue: selectedDate.wrappedValue)
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        return Array(symbols[1...]) + [symbols[0]]
    }

    /// Full weeks covering the displayed month: `nil` entries are adjacent-month padding so the
    /// grid always starts on a Monday and ends on a Sunday.
    private var monthGridDates: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: leadingBlanks)
        var current = firstOfMonth
        while current < monthInterval.end {
            days.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        while days.count % 7 != 0 {
            days.append(nil)
        }
        return days
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                monthHeader
                weekdayHeader
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(Array(monthGridDates.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear.frame(height: 52)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 32)
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
            Spacer()
            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 32)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func changeMonth(by delta: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }

    /// Same five-way scheme as `WeekStripView`'s dots: grey for no entries, the faded/bold
    /// salmon pair for over-target, the faded/bold green pair for under-target — bold reserved
    /// for the currently viewed (`isSelected`) day.
    private func dotColor(isSelected: Bool, hasEntries: Bool, isOver: Bool) -> Color {
        guard hasEntries else { return .dashboardEmptyTrack }
        if isOver { return isSelected ? .brandProtein : .dashboardOverFill }
        return isSelected ? .dashboardAccent : .dashboardBarFill
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let isInDisplayedMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let hasEntries = daysWithEntries.contains(day.startOfDay)
        let isOver = daysOverTarget.contains(day.startOfDay)

        Button {
            selectedDate = day
            dismiss()
        } label: {
            // Spacing has to clear the "today" ring, not just the dot: the ring is an overlay
            // inset by -3, so it paints 3pt outside the circle while taking no layout space of
            // its own, and a 2pt gap left it sitting right on top of the date underneath.
            VStack(spacing: 6) {
                Circle()
                    .fill(dotColor(isSelected: isSelected, hasEntries: hasEntries, isOver: isOver))
                    .frame(width: 34, height: 34)
                    .opacity(isInDisplayedMonth ? 1 : 0.3)
                    .overlay {
                        if isToday {
                            Circle().stroke(Color.accentColor, lineWidth: 1.5).padding(-3)
                        }
                    }
                Text("\(calendar.component(.day, from: day))")
                    .font(.caption2)
                    .foregroundStyle(isInDisplayedMonth ? .primary : .secondary)
            }
            .padding(6)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isInDisplayedMonth)
        .accessibilityLabel(day.formatted(.dateTime.month(.wide).day()))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
