import Testing
@testable import MealTracker

struct EnergyAdjustmentCalculatorTests {
    @Test func maintainReturnsBmrPlusActiveEnergy() {
        let result = EnergyAdjustmentCalculator.adjustedCalorieTarget(bmr: 1500, activeEnergyBurnedToday: 400, goal: .maintain, goalRateKgPerWeek: 0)
        #expect(abs(result - 1900) < 0.001)
    }

    @Test func loseSubtractsDailyDeltaFromMaintenance() {
        // dailyDelta = (0.5 * 7700) / 7 = 550
        let result = EnergyAdjustmentCalculator.adjustedCalorieTarget(bmr: 1500, activeEnergyBurnedToday: 400, goal: .lose, goalRateKgPerWeek: 0.5)
        #expect(abs(result - 1350) < 0.001)
    }

    @Test func gainAddsDailyDeltaToMaintenance() {
        // dailyDelta = (0.5 * 7700) / 7 = 550
        let result = EnergyAdjustmentCalculator.adjustedCalorieTarget(bmr: 1500, activeEnergyBurnedToday: 400, goal: .gain, goalRateKgPerWeek: 0.5)
        #expect(abs(result - 2450) < 0.001)
    }

    @Test func zeroActiveEnergyStillReturnsBmrBasedMaintenance() {
        let result = EnergyAdjustmentCalculator.adjustedCalorieTarget(bmr: 1500, activeEnergyBurnedToday: 0, goal: .maintain, goalRateKgPerWeek: 0)
        #expect(abs(result - 1500) < 0.001)
    }
}
