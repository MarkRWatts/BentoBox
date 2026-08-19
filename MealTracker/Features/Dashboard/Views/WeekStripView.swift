import SwiftUI
import UIKit

/// Continuously scrollable day strip styled after the Apple Health day picker: a big
/// relative-date heading, then a caret fixed at the horizontal center with a row of weekday
/// initials and a row of dots (filled when that day has logged entries, matching
/// `MonthCalendarView`'s dots) scrolling underneath it. Scrolling changes which day sits under
/// the fixed caret, snapping one day at a time, rather than paging whole calendar weeks.
/// Monday-first is hardcoded (not the device locale's first weekday) to match the Mon–Sun layout
/// used throughout this feature.
struct WeekStripView: View {
    @Binding var selectedDate: Date
    let profile: UserProfile
    let entries: [LoggedEntry]

    /// ~2 years back and forward — generous enough nobody hits the edge in practice, cheap since
    /// only the visible columns are ever actually rendered.
    private let dayOffsetRange = -730...730
    @State private var scrolledDayOffset: Int?

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    private var today: Date { Date().startOfDay }

    private func date(forOffset offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func dayOffset(for date: Date) -> Int {
        calendar.dateComponents([.day], from: today, to: date.startOfDay).day ?? 0
    }

    private var selectedDayOffset: Int { dayOffset(for: selectedDate) }

    private var headingText: String {
        let relativeLabel: String
        if calendar.isDateInToday(selectedDate) {
            relativeLabel = "Today"
        } else if calendar.isDateInYesterday(selectedDate) {
            relativeLabel = "Yesterday"
        } else {
            relativeLabel = selectedDate.formatted(.dateTime.weekday(.wide))
        }
        return "\(relativeLabel), \(selectedDate.formatted(.dateTime.day().month(.wide)))"
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(headingText)
                .font(.title.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)

            Divider()

            ZStack(alignment: .top) {
                GeometryReader { geometry in
                    let columnWidth = geometry.size.width / 7
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(dayOffsetRange, id: \.self) { offset in
                                dayCell(date(forOffset: offset))
                                    .frame(width: columnWidth)
                                    .id(offset)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollPosition(id: $scrolledDayOffset, anchor: .center)
                    .safeAreaPadding(.horizontal, columnWidth * 3)
                }

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
            .frame(height: 92)
        }
        .onAppear {
            scrolledDayOffset = selectedDayOffset
        }
        .onChange(of: scrolledDayOffset) { _, newOffset in
            guard let newOffset else { return }
            selectedDate = date(forOffset: newOffset)
        }
        .onChange(of: selectedDate) { _, _ in
            if scrolledDayOffset != selectedDayOffset {
                withAnimation {
                    scrolledDayOffset = selectedDayOffset
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let hasEntries = DayProgressCalculator.dayProgress(for: day, profile: profile, entries: entries).hasEntries
        Button {
            selectedDate = day
        } label: {
            VStack(spacing: 8) {
                Text(day.formatted(.dateTime.weekday(.narrow)))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .secondary)
                    .frame(width: 28, height: 28)
                    .background {
                        if isSelected {
                            Circle().fill(Color.primary)
                        }
                    }
                    .padding(.top, 12)

                Circle()
                    .fill(hasEntries ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 44, height: 44)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day()))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
