import Testing
import Foundation
@testable import MealTracker

struct FastingTimerCalculatorTests {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func now(hoursAfterStart hours: Double) -> Date {
        start.addingTimeInterval(hours * 3600)
    }

    @Test func elapsedAndFractionTrackTheGoal() {
        let progress = FastingTimerCalculator.progress(startedAt: start, goalHours: 16, now: now(hoursAfterStart: 8))

        #expect(progress.elapsed == 8 * 3600)
        #expect(progress.fraction == 0.5)
        #expect(progress.remaining == 8 * 3600)
        #expect(progress.hasReachedGoal == false)
    }

    @Test func goalIsReachedExactlyOnTheHour() {
        let progress = FastingTimerCalculator.progress(startedAt: start, goalHours: 16, now: now(hoursAfterStart: 16))

        #expect(progress.hasReachedGoal)
        #expect(progress.remaining == 0)
    }

    @Test func fractionAndRemainingStayClampedPastTheGoal() {
        let progress = FastingTimerCalculator.progress(startedAt: start, goalHours: 16, now: now(hoursAfterStart: 20))

        #expect(progress.fraction == 1)
        #expect(progress.remaining == 0)
        #expect(progress.elapsed == 20 * 3600)
    }

    /// A start edited to the future (or a device clock that jumped) must read as a fast that
    /// hasn't started, never as a negative countdown.
    @Test func aStartInTheFutureClampsToZeroElapsed() {
        let progress = FastingTimerCalculator.progress(startedAt: start, goalHours: 16, now: now(hoursAfterStart: -3))

        #expect(progress.elapsed == 0)
        #expect(progress.fraction == 0)
        #expect(progress.remaining == 16 * 3600)
    }

    @Test func durationTextFormatsHoursAndPaddedMinutes() {
        #expect(FastingTimerCalculator.durationText(16 * 3600 + 4 * 60) == "16h 04m")
    }

    @Test func durationTextDropsTheHourComponentUnderAnHour() {
        #expect(FastingTimerCalculator.durationText(48 * 60) == "48m")
    }

    @Test func preciseDurationTextIncludesSeconds() {
        #expect(FastingTimerCalculator.preciseDurationText(3 * 3600 + 7 * 60 + 5) == "3h 07m 05s")
    }

    @Test func goalLabelNamesTheFastingEatingSplit() {
        #expect(FastingTimerCalculator.goalLabel(hours: 16) == "16:8")
        #expect(FastingTimerCalculator.goalLabel(hours: 18) == "18:6")
    }

    @Test func goalLabelFallsBackToALengthWhenThereIsNoEatingWindow() {
        #expect(FastingTimerCalculator.goalLabel(hours: 24) == "24h")
    }
}
