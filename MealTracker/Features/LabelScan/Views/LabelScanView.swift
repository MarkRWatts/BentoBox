import SwiftUI
import SwiftData
import PhotosUI
import AVFoundation

struct LabelScanView: View {
    let mealSlot: MealSlotConfig

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = LabelScanViewModel()
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isPresentingManualEntry = false

    private var isCameraAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .idle:
                    idleContent
                case .processing:
                    ProgressView("Reading label…")
                case .ready(let extracted):
                    LabelExtractionReviewView(extracted: extracted, mealSlot: mealSlot, onSaved: dismiss.callAsFunction)
                case .unavailable(let message):
                    ContentUnavailableView {
                        Label("Apple Intelligence Unavailable", systemImage: "apple.intelligence")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { viewModel.reset() }
                        Button("Enter Manually") { isPresentingManualEntry = true }
                    }
                case .error(let message):
                    ContentUnavailableView {
                        Label("Couldn't Read Label", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") { viewModel.reset() }
                        Button("Enter Manually") { isPresentingManualEntry = true }
                    }
                }
            }
            .navigationTitle("Scan Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $isPresentingManualEntry) {
                ManualFoodEntryView(mealSlot: mealSlot, onSaved: dismiss.callAsFunction)
            }
        }
    }

    @ViewBuilder
    private var idleContent: some View {
        Group {
            if isCameraAvailable {
                ZStack(alignment: .bottomLeading) {
                    LabelCameraView { image in
                        Task { await viewModel.process(image: image) }
                    }
                    .ignoresSafeArea()

                    // A photo-library shortcut alongside the shutter — not just a no-camera
                    // fallback. Re-picking the same saved reference photo each time (rather than
                    // re-photographing the label) is what makes extraction fixes actually
                    // comparable against each other, run to run.
                    PhotosPicker(selection: $photosPickerItem, matching: .images) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.leading, 24)
                    .padding(.bottom, 48)
                }
            } else {
                // No camera (e.g. Simulator) — fall back to picking an existing photo.
                VStack(spacing: 16) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Choose a photo of a nutrition label")
                        .foregroundStyle(.secondary)
                    PhotosPicker("Choose Photo", selection: $photosPickerItem, matching: .images)
                        .buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                guard let newItem,
                      let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                await viewModel.process(image: image)
            }
        }
    }
}
