import Testing
import Foundation
@testable import MealTracker

struct WaterIntakeCalculatorTests {
    private func entry(volumeML: Double, daysAgo: Int = 0, hour: Int = 12) -> WaterLogEntry {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
        return WaterLogEntry(date: date, volumeML: volumeML)
    }

    @Test func totalSumsOnlyThatDaysEntries() {
        let entries = [entry(volumeML: 250), entry(volumeML: 500), entry(volumeML: 1000, daysAgo: 1)]

        #expect(WaterIntakeCalculator.totalML(entries: entries, on: Date()) == 750)
    }

    @Test func totalIsZeroForADayWithNothingLogged() {
        let entries = [entry(volumeML: 250, daysAgo: 3)]

        #expect(WaterIntakeCalculator.totalML(entries: entries, on: Date()) == 0)
    }

    @Test func totalCountsEntriesAnywhereInTheDayNotJustMidday() {
        let entries = [entry(volumeML: 250, hour: 0), entry(volumeML: 250, hour: 23)]

        #expect(WaterIntakeCalculator.totalML(entries: entries, on: Date()) == 500)
    }

    @Test func progressIsTheFractionOfTarget() {
        #expect(WaterIntakeCalculator.progress(consumedML: 500, targetML: 2000) == 0.25)
    }

    @Test func progressClampsAtFullWhenOverTarget() {
        #expect(WaterIntakeCalculator.progress(consumedML: 3000, targetML: 2000) == 1)
    }

    @Test func progressIsZeroForANonsenseTarget() {
        #expect(WaterIntakeCalculator.progress(consumedML: 500, targetML: 0) == 0)
    }

    @Test func glassesCompletedRoundsDownToWholeGlasses() {
        #expect(WaterIntakeCalculator.glassesCompleted(consumedML: 600, servingML: 250) == 2)
    }

    /// Guards the floating-point nudge: eight 250ml glasses summed as Doubles must read as 8,
    /// not 7, or the last glass glyph would refuse to fill on a completed target.
    @Test func glassesCompletedCountsAnExactlyMetTarget() {
        let consumed = (0..<8).reduce(0.0) { total, _ in total + 250 }

        #expect(WaterIntakeCalculator.glassesCompleted(consumedML: consumed, servingML: 250) == 8)
    }

    @Test func glassesCompletedIsZeroBeforeTheFirstFullGlass() {
        #expect(WaterIntakeCalculator.glassesCompleted(consumedML: 100, servingML: 250) == 0)
    }

    @Test func glassesInTargetRoundsUpSoTheTargetIsAlwaysCovered() {
        #expect(WaterIntakeCalculator.glassesInTarget(targetML: 2000, servingML: 300) == 7)
    }

    @Test func glassesInTargetCapsTheRowLength() {
        #expect(WaterIntakeCalculator.glassesInTarget(targetML: 6000, servingML: 100) == 10)
    }
}
