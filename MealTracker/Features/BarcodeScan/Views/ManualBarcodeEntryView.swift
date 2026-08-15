import SwiftUI

struct ManualBarcodeEntryView: View {
    @Binding var barcode: String
    var onSubmit: () -> Void

    var body: some View {
        Form {
            Section("Barcode") {
                TextField("Barcode Number", text: $barcode)
                    .keyboardType(.numberPad)
            }
            Section {
                Button("Look Up") { onSubmit() }
                    .disabled(barcode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}
