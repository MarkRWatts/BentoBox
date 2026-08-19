import SwiftUI
import UIKit

/// Continuously scrollable day strip styled after the Apple Health day picker: a big
/// relative-date heading (with the calendar-picker button on the same line, rather than
/// duplicating the date again in the navigation bar above it), then a caret fixed at the
/// horizontal center with a row of weekday initials and a row of dots (filled when that day has
/// logged entries, matching `MonthCalendarView`'s dots) scrolling underneath it. Scrolling
/// changes which day sits under the fixed caret, snapping one day at a time, rather than paging
/// whole calendar weeks. Monday-first is hardcoded (not the device locale's first weekday) to
/// match the Mon–Sun layout used throughout this feature.
struct WeekStripView: View {
    @Binding var selectedDate: Date
    let profile: UserProfile
    let entries: [LoggedEntry]
    var onTapCalendar: () -> Void

    /// ~2 years back and forward — generous enough nobody hits the edge in practice, cheap since
    /// only the visible columns are ever actually rendered.
    private let dayOffsetRange = -730...730
    @State private var scrolledDayOffset: Int?

    init(selectedDate: Binding<Date>, profile: UserProfile, entries: [LoggedEntry], onTapCalendar: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self.profile = profile
        self.entries = entries
        self.onTapCalendar = onTapCalendar
        // Seeded directly as the initial `@State` value rather than assigned in `.onAppear` —
        // `.scrollPosition(id:anchor:.center)` needs `scrolledDayOffset` already populated before
        // the scroll view's very first layout pass to center on it reliably. Setting it in
        // `.onAppear` races that first layout (which itself waits on the `GeometryReader`-derived
        // column width) and would silently leave the strip un-centered on a cold launch.
        self._scrolledDayOffset = State(initialValue: Self.dayOffset(for: selectedDate.wrappedValue))
    }

    private static var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }

    private static var today: Date { Date().startOfDay }

    private static func dayOffset(for date: Date) -> Int {
        calendar.dateComponents([.day], from: today, to: date.startOfDay).day ?? 0
    }

    private var calendar: Calendar { Self.calendar }
    private var today: Date { Self.today }

    private func date(forOffset offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    private func dayOffset(for date: Date) -> Int {
        Self.dayOffset(for: date)
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
            HStack(alignment: .center) {
                Text(headingText)
                    .font(.archivo(30, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Spacer()
                Button(action: onTapCalendar) {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.dashboardAccent)
                        .frame(width: 38, height: 38)
                        .background(Color.dashboardCard, in: Circle())
                }
                .accessibilityLabel("Choose Date")
            }
            .padding(.horizontal)
            .padding(.top, 16)

            Rectangle()
                .fill(Color.dashboardDivider)
                .frame(height: 1)

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
                    .font(.manrope(13, weight: .bold))
                    .foregroundStyle(isSelected ? Color.dashboardCard : Color.dashboardInkSecondary)
                    .frame(width: 28, height: 28)
                    .background {
                        if isSelected {
                            Circle().fill(Color.dashboardInk)
                        }
                    }
                    .padding(.top, 12)

                Circle()
                    .fill(hasEntries ? Color.dashboardAccent : Color.dashboardBarTrack)
                    .frame(width: 44, height: 44)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day()))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
