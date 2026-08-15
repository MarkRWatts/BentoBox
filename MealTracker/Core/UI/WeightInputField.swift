import SwiftUI

/// Weight entry that adapts to the profile's chosen display unit while always writing back a
/// canonical kg value — stone needs two components (stone + pounds), so this can't be a single
/// bound TextField the way kg/lb can.
struct WeightInputField: View {
    let unit: WeightUnit
    @Binding var weightKG: Double

    var body: some View {
        switch unit {
        case .kilograms:
            singleField(label: "Weight (kg)", value: $weightKG)
        case .pounds:
            singleField(label: "Weight (lb)", value: poundsBinding)
        case .stone:
            HStack {
                Text("Weight")
                Spacer()
                TextField("st", value: stoneBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 40)
                Text("st")
                    .foregroundStyle(.secondary)
                TextField("lb", value: stoneRemainderPoundsBinding, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                Text("lb")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func singleField(label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: value, format: .number.precision(.fractionLength(1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }

    private var poundsBinding: Binding<Double> {
        Binding(
            get: { UnitConversion.kgToPounds(weightKG) },
            set: { weightKG = UnitConversion.poundsToKg($0) }
        )
    }

    private var stoneBinding: Binding<Int> {
        Binding(
            get: { UnitConversion.kgToStoneAndPounds(weightKG).stone },
            set: { newStone in
                let currentPounds = UnitConversion.kgToStoneAndPounds(weightKG).pounds
                weightKG = UnitConversion.stoneAndPoundsToKg(stone: newStone, pounds: currentPounds)
            }
        )
    }

    private var stoneRemainderPoundsBinding: Binding<Double> {
        Binding(
            get: { UnitConversion.kgToStoneAndPounds(weightKG).pounds },
            set: { newPounds in
                let currentStone = UnitConversion.kgToStoneAndPounds(weightKG).stone
                weightKG = UnitConversion.stoneAndPoundsToKg(stone: currentStone, pounds: newPounds)
            }
        )
    }
}
