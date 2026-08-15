import Testing
@testable import MealTracker

struct BMICalculatorTests {
    @Test func bmiKnownValue() {
        // 70 / 1.75^2 = 22.857...
        let result = BMICalculator.bmi(weightKG: 70, heightCM: 175)
        #expect(abs(result - 22.857) < 0.001)
    }

    @Test func bmiReturnsZeroForNonPositiveHeight() {
        #expect(BMICalculator.bmi(weightKG: 70, heightCM: 0) == 0)
        #expect(BMICalculator.bmi(weightKG: 70, heightCM: -10) == 0)
    }

    @Test func categoryClassifiesUnderweight() {
        #expect(BMICalculator.category(for: 16.3) == .underweight)
        #expect(BMICalculator.category(for: 18.49) == .underweight)
    }

    @Test func categoryClassifiesNormalIncludingLowerBoundary() {
        #expect(BMICalculator.category(for: 18.5) == .normal)
        #expect(BMICalculator.category(for: 22.9) == .normal)
        #expect(BMICalculator.category(for: 24.99) == .normal)
    }

    @Test func categoryClassifiesOverweightIncludingLowerBoundary() {
        #expect(BMICalculator.category(for: 25.0) == .overweight)
        #expect(BMICalculator.category(for: 27.8) == .overweight)
        #expect(BMICalculator.category(for: 29.99) == .overweight)
    }

    @Test func categoryClassifiesObeseIncludingLowerBoundary() {
        #expect(BMICalculator.category(for: 30.0) == .obese)
        #expect(BMICalculator.category(for: 40.0) == .obese)
    }

    @Test func weightForBMIIsInverseOfBMI() {
        let heightCM = 175.0
        let weightKG = BMICalculator.weight(forBMI: 22.857, heightCM: heightCM)
        #expect(abs(weightKG - 70) < 0.01)
        #expect(abs(BMICalculator.bmi(weightKG: weightKG, heightCM: heightCM) - 22.857) < 0.01)
    }

    @Test func weightForBMIReturnsZeroForNonPositiveHeight() {
        #expect(BMICalculator.weight(forBMI: 22, heightCM: 0) == 0)
    }

    @Test func normalRangeMidpointIsCenteredOnNormalRange() {
        #expect(BMICalculator.normalRangeMidpointBMI == 21.75)
        #expect(BMICalculator.category(for: BMICalculator.normalRangeMidpointBMI) == .normal)
    }
}
