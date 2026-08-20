import Testing
@testable import MealTracker

struct UnitConversionTests {
    @Test func kgToPoundsKnownValue() {
        // 70 kg ≈ 154.32 lb
        let result = UnitConversion.kgToPounds(70)
        #expect(abs(result - 154.324) < 0.01)
    }

    @Test func poundsToKgRoundTripsWithKgToPounds() {
        let original = 82.4
        let roundTripped = UnitConversion.poundsToKg(UnitConversion.kgToPounds(original))
        #expect(abs(roundTripped - original) < 0.0001)
    }

    @Test func kgToStoneAndPoundsKnownValue() {
        // 70 kg ≈ 154.32 lb = 11 st 0.32 lb
        let result = UnitConversion.kgToStoneAndPounds(70)
        #expect(result.stone == 11)
        #expect(abs(result.pounds - 0.324) < 0.01)
    }

    @Test func stoneAndPoundsToKgRoundTripsWithKgToStoneAndPounds() {
        let original = 82.4
        let (stone, pounds) = UnitConversion.kgToStoneAndPounds(original)
        let roundTripped = UnitConversion.stoneAndPoundsToKg(stone: stone, pounds: pounds)
        #expect(abs(roundTripped - original) < 0.0001)
    }

    @Test func cmToInchesKnownValue() {
        // 175 cm ≈ 68.9 in
        let result = UnitConversion.cmToInches(175)
        #expect(abs(result - 68.898) < 0.01)
    }

    @Test func cmToFeetAndInchesKnownValue() {
        // 175 cm ≈ 5'8.9"
        let result = UnitConversion.cmToFeetAndInches(175)
        #expect(result.feet == 5)
        #expect(abs(result.inches - 8.898) < 0.01)
    }

    @Test func feetAndInchesToCmRoundTripsWithCmToFeetAndInches() {
        let original = 182.3
        let (feet, inches) = UnitConversion.cmToFeetAndInches(original)
        let roundTripped = UnitConversion.feetAndInchesToCm(feet: feet, inches: inches)
        #expect(abs(roundTripped - original) < 0.0001)
    }

    @Test func mlToFluidOuncesKnownValue() {
        // 500 ml ≈ 16.9 US fl oz
        #expect(abs(UnitConversion.mlToFluidOunces(500) - 16.907) < 0.01)
    }

    @Test func fluidOuncesToMLRoundTripsWithMLToFluidOunces() {
        let original = 473.2
        let roundTripped = UnitConversion.fluidOuncesToML(UnitConversion.mlToFluidOunces(original))
        #expect(abs(roundTripped - original) < 0.0001)
    }

    @Test func volumeUnitFormatsAStoredMLValueInThePreferredUnit() {
        #expect(VolumeUnit.milliliters.displayString(fromML: 250) == "250 ml")
        #expect(VolumeUnit.fluidOunces.displayString(fromML: 250) == "8 fl oz")
    }
}
