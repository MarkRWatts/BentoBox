import SwiftUI

struct ProductNotFoundView: View {
    let barcode: String
    let mealSlot: MealSlotConfig
    var date: Date = Date()
    var onLogged: () -> Void
    var onRetry: () -> Void

    @State private var isShowingManualFoodEntry = false

    var body: some View {
        ContentUnavailableView {
            Label("Product Not Found", systemImage: "barcode")
        } description: {
            Text("No product was found for barcode \(barcode). You can add it manually — it'll be remembered next time you scan it.")
        } actions: {
            Button("Add Manually") {
                isShowingManualFoodEntry = true
            }
            Button("Try Another Barcode") {
                onRetry()
            }
        }
        .sheet(isPresented: $isShowingManualFoodEntry) {
            ManualFoodEntryView(mealSlot: mealSlot, date: date, prefilledBarcode: barcode, onSaved: onLogged)
        }
    }
}
