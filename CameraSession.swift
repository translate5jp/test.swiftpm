import AVFoundation
import UIKit

/// AVFoundation カメラセッション管理
class CameraSession: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()
    @Published var capturedFrames: [UIImage] = []
    @Published var isAuthorized = false

    private let sessionQueue = DispatchQueue(label: "cam.io", qos: .userInitiated)
    private var pendingCapture = false

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
        output.setSampleBufferDelegate(self, queue: sessionQueue)
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }

        captureSession.commitConfiguration()
    }

    func start() {
        guard !captureSession.isRunning else { return }
        sessionQueue.async { self.captureSession.startRunning() }
    }

    func stop() {
        guard captureSession.isRunning else { return }
        sessionQueue.async { self.captureSession.stopRunning() }
    }

    func captureFrame() {
        pendingCapture = true
    }

    func reset() {
        DispatchQueue.main.async { self.capturedFrames = [] }
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard pendingCapture else { return }
        pendingCapture = false

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return }

        // バックカメラのポートレートでは .right が正位置
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        DispatchQueue.main.async { self.capturedFrames.append(image) }
    }
}
