import SwiftUI

/// Height entry that adapts to the profile's chosen display unit while always writing back a
/// canonical cm value — feet/inches needs two components, so this can't be a single bound
/// TextField the way cm can.
struct HeightInputField: View {
    let unit: HeightUnit
    @Binding var heightCM: Double

    var body: some View {
        switch unit {
        case .centimeters:
            HStack {
                Text("Height (cm)")
                Spacer()
                TextField("Height", value: $heightCM, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        case .feetInches:
            HStack {
                Text("Height")
                Spacer()
                TextField("ft", value: feetBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 32)
                    .fixedSize(horizontal: true, vertical: false)
                Text("ft")
                    .foregroundStyle(.secondary)
                TextField("in", value: feetRemainderInchesBinding, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 40)
                    .fixedSize(horizontal: true, vertical: false)
                Text("in")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var feetBinding: Binding<Int> {
        Binding(
            get: { UnitConversion.cmToFeetAndInches(heightCM).feet },
            set: { newFeet in
                let currentInches = UnitConversion.cmToFeetAndInches(heightCM).inches
                heightCM = UnitConversion.feetAndInchesToCm(feet: newFeet, inches: currentInches)
            }
        )
    }

    private var feetRemainderInchesBinding: Binding<Double> {
        Binding(
            get: { UnitConversion.cmToFeetAndInches(heightCM).inches },
            set: { newInches in
                let currentFeet = UnitConversion.cmToFeetAndInches(heightCM).feet
                heightCM = UnitConversion.feetAndInchesToCm(feet: currentFeet, inches: newInches)
            }
        )
    }
}
