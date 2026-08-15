import SwiftUI
import AVFoundation

/// A minimal custom camera (rather than UIImagePickerController, which doesn't support overlays
/// well) so we can draw a guide rectangle over the live preview and crop the captured photo to
/// it. Real-device testing on label scanning showed accuracy is very sensitive to how much of
/// the surrounding packaging (ingredients lists, allergen text, certification blurbs) ends up in
/// frame alongside the nutrition table — letting the user frame just the table before capture,
/// and discarding everything outside that frame, cuts down on both OCR noise and how much
/// unrelated text ever reaches the extraction model.
struct LabelCameraView: View {
    var onCapture: (UIImage) -> Void

    @State private var controller = LabelCameraController()
    @State private var isCapturing = false

    /// Nutrition tables are usually taller than wide, so the guide is a portrait rectangle
    /// covering most of the screen width.
    private let guideWidthFraction: CGFloat = 0.85
    private let guideAspectRatio: CGFloat = 0.72 // width / height

    var body: some View {
        GeometryReader { geometry in
            let guide = guideRect(in: geometry.size)

            ZStack {
                CameraPreviewView(session: controller.session)
                    .ignoresSafeArea()

                GuideOverlay(rect: guide)

                VStack {
                    Spacer()
                    Text("Fit the nutrition table inside the frame")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 24)

                    Button {
                        capture(screenSize: geometry.size)
                    } label: {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                            .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 2))
                    }
                    .disabled(isCapturing)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
    }

    private func guideRect(in screenSize: CGSize) -> CGRect {
        let width = screenSize.width * guideWidthFraction
        let height = width / guideAspectRatio
        return CGRect(
            x: (screenSize.width - width) / 2,
            y: (screenSize.height - height) / 2,
            width: width,
            height: height
        )
    }

    private func capture(screenSize: CGSize) {
        guard !isCapturing else { return }
        isCapturing = true
        let guide = guideRect(in: screenSize)
        Task {
            let image = await controller.capturePhoto()
            isCapturing = false
            guard let image else { return }
            onCapture(LabelImageCropper.crop(image: image, toGuideRect: guide, screenSize: screenSize) ?? image)
        }
    }
}

private struct GuideOverlay: View {
    let rect: CGRect

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
            RoundedRectangle(cornerRadius: 16)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

/// Plain NSObject, marked `@unchecked Sendable` since AVCaptureSession predates Swift Concurrency
/// and isn't itself Sendable-audited — this class is responsible for its own thread-safety, and
/// does so via a CheckedContinuation (rather than a stored closure + manual queue hop), which is
/// specifically designed for bridging a delegate callback on an arbitrary queue into async/await
/// without tripping Swift 6's Sendable checking.
final class LabelCameraController: NSObject, @unchecked Sendable {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var continuation: CheckedContinuation<UIImage?, Never>?

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }
    }

    func start() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
    }

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }
}

extension LabelCameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image: UIImage? = {
            guard error == nil, let data = photo.fileDataRepresentation() else { return nil }
            return UIImage(data: data)
        }()
        continuation?.resume(returning: image)
        continuation = nil
    }
}
