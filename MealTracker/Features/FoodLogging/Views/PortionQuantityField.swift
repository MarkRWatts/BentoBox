import SwiftUI

/// Quantity entry for a logged portion. When the food's serving size has a known gram basis
/// (either a parsed label serving size, or Open Food Facts' 100g reporting fallback), lets the
/// user type the actual amount eaten in grams instead of picking a "servings" count — the
/// natural way to enter a real-world amount like 130g that isn't a round multiple of whatever
/// basis the nutrition happens to be reported against. Falls back to the previous servings
/// stepper for foods sold in genuinely discrete, non-gram units ("1 bar", "1 cup").
struct PortionQuantityField: View {
    @Binding var quantity: Double
    /// The gram weight that `quantity == 1` represents. Nil for discrete non-gram servings.
    let servingSizeGrams: Double?

    var body: some View {
        if let servingSizeGrams, servingSizeGrams > 0 {
            GramsQuantityField(quantity: $quantity, servingSizeGrams: servingSizeGrams)
        } else {
            Stepper(value: $quantity, in: 0.25...20, step: 0.25) {
                Text("Servings: \(quantity, specifier: "%.2f")")
            }
        }
    }
}

private struct GramsQuantityField: View {
    @Binding var quantity: Double
    let servingSizeGrams: Double

    /// Own text buffer rather than binding the `TextField` straight to a formatted `quantity` —
    /// otherwise every keystroke's round-trip through the formatter fights the user mid-edit
    /// (e.g. typing "130" reformatting through "13" then "130" as `quantity` recomputes).
    @State private var gramsText: String = ""

    var body: some View {
        HStack {
            Text("Amount")
            Spacer()
            TextField("Grams", text: $gramsText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .onChange(of: gramsText) { _, newValue in
                    guard let grams = Double(newValue) else { return }
                    quantity = grams / servingSizeGrams
                }
            Text("g")
                .foregroundStyle(.secondary)
        }
        .onAppear {
            // Defaults to exactly one serving's worth of grams, matching `quantity`'s own
            // starting value of 1 everywhere this is used.
            gramsText = formatted(quantity * servingSizeGrams)
        }

        Text("= \(quantity, specifier: "%.2f") servings")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
}
