import SwiftUI

/// Horizontally paged Mon–Sun week strip. Swiping to a new week preserves the selected weekday
/// index (e.g. Wed → next week's Wed) rather than resetting to Monday, so the highlighted cell
/// never jumps unexpectedly. Monday-first is hardcoded (not the device locale's first weekday) to
/// match the Mon–Sun layout used throughout this feature.
struct WeekStripView: View {
    @Binding var selectedDate: Date
    let profile: UserProfile
    let entries: [LoggedEntry]

    /// ~2 years back and forward — generous enough nobody hits the edge in practice, cheap since
    /// only the visible page's 7 glyphs are ever actually rendered.
    private let weekOffsetRange = -104...104
    @State private var scrolledWeekOffset: Int?

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    private func weekStart(of date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date.startOfDay
    }

    private var currentWeekStart: Date { weekStart(of: Date()) }

    private func weekStart(forOffset offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset * 7, to: currentWeekStart) ?? currentWeekStart
    }

    private func dates(forOffset offset: Int) -> [Date] {
        let start = weekStart(forOffset: offset)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var selectedWeekdayIndex: Int {
        calendar.dateComponents([.day], from: weekStart(of: selectedDate), to: selectedDate.startOfDay).day ?? 0
    }

    private var selectedWeekOffset: Int {
        let days = calendar.dateComponents([.day], from: currentWeekStart, to: weekStart(of: selectedDate)).day ?? 0
        return days / 7
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(weekOffsetRange, id: \.self) { offset in
                    weekPage(forOffset: offset)
                        .containerRelativeFrame(.horizontal)
                        .id(offset)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolledWeekOffset)
        .frame(height: 68)
        .onAppear {
            scrolledWeekOffset = selectedWeekOffset
        }
        .onChange(of: scrolledWeekOffset) { _, newOffset in
            guard let newOffset else { return }
            let newWeekStart = weekStart(forOffset: newOffset)
            if let newSelected = calendar.date(byAdding: .day, value: selectedWeekdayIndex, to: newWeekStart) {
                selectedDate = newSelected
            }
        }
        .onChange(of: selectedDate) { _, _ in
            if scrolledWeekOffset != selectedWeekOffset {
                withAnimation {
                    scrolledWeekOffset = selectedWeekOffset
                }
            }
        }
    }

    @ViewBuilder
    private func weekPage(forOffset offset: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(dates(forOffset: offset), id: \.self) { day in
                dayCell(day)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        Button {
            selectedDate = day
        } label: {
            VStack(spacing: 4) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                DayProgressRingGlyph(
                    progress: DayProgressCalculator.dayProgress(for: day, profile: profile, entries: entries),
                    size: 30
                )
                .overlay {
                    if isToday {
                        Circle().stroke(Color.accentColor, lineWidth: 1.5).padding(-3)
                    }
                }
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.12))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day()))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
