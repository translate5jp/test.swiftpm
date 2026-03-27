import AVFoundation
import UIKit

/// AVFoundation カメラセッション管理
class CameraSession: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    @Published var frames: [UIImage] = []
    @Published var isAuthorized = false

    private let queue = DispatchQueue(label: "cam.io", qos: .userInitiated)
    private var wantCapture = false

    func setup() async {
        let authorized: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorized = true
        case .notDetermined:
            authorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            authorized = false
        }
        await MainActor.run { isAuthorized = authorized }
        guard authorized else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }

        captureSession.commitConfiguration()
    }

    func start() {
        guard !captureSession.isRunning else { return }
        queue.async { self.captureSession.startRunning() }
    }

    func stop() {
        guard captureSession.isRunning else { return }
        queue.async { self.captureSession.stopRunning() }
    }

    func captureFrame() {
        wantCapture = true
    }

    func reset() {
        DispatchQueue.main.async { self.frames = [] }
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard wantCapture else { return }
        wantCapture = false

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return }

        // バックカメラのポートレートでは .right が正位置
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        DispatchQueue.main.async { self.frames.append(image) }
    }
}
