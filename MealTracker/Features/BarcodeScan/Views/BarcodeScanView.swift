import SwiftUI
import SwiftData
import VisionKit

struct BarcodeScanView: View {
    let mealSlot: MealSlotConfig

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = BarcodeScanViewModel()
    @State private var manualBarcode = ""
    @State private var isShowingManualEntry = false

    private var isScannerSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle:
                    idleContent
                case .lookingUp:
                    ProgressView("Looking up product…")
                case .found(let foodItem):
                    ProductLookupResultView(foodItem: foodItem, mealSlot: mealSlot, onLogged: dismiss.callAsFunction)
                case .notFound(let barcode):
                    ProductNotFoundView(
                        barcode: barcode,
                        mealSlot: mealSlot,
                        onLogged: dismiss.callAsFunction,
                        onRetry: viewModel.reset
                    )
                case .error(let message):
                    ContentUnavailableView {
                        Label("Lookup Failed", systemImage: "wifi.slash")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { viewModel.reset() }
                    }
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var idleContent: some View {
        if isScannerSupported {
            ZStack(alignment: .bottom) {
                BarcodeScannerView { barcode in
                    Task { await viewModel.lookup(barcode: barcode, context: modelContext) }
                }
                .ignoresSafeArea()

                Button("Enter Barcode Manually") {
                    isShowingManualEntry = true
                }
                .buttonStyle(.glass)
                .padding(.bottom, 32)
            }
            .sheet(isPresented: $isShowingManualEntry) {
                ManualBarcodeEntryView(barcode: $manualBarcode) {
                    isShowingManualEntry = false
                    Task { await viewModel.lookup(barcode: manualBarcode, context: modelContext) }
                }
            }
        } else {
            ManualBarcodeEntryView(barcode: $manualBarcode) {
                Task { await viewModel.lookup(barcode: manualBarcode, context: modelContext) }
            }
        }
    }
}
