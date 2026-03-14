import CoreMotion
import Foundation

/// CMMotionManager を使って水平方向の回転を検出し、一定角度ごとに撮影をトリガーする
class MotionDetector: ObservableObject {
    @Published var captureCount: Int = 0

    private let motionManager = CMMotionManager()
    private var previousYaw: Double?

    /// フレーム間の角度（度）。この値ごとに `onCapture` が呼ばれる
    let captureAngle: Double = 12.0
    var onCapture: (() -> Void)?

    var isAvailable: Bool { motionManager.isDeviceMotionAvailable }

    func start() {
        guard isAvailable else { return }
        previousYaw = nil
        motionManager.deviceMotionUpdateInterval = 1.0 / 30
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.handleMotionUpdate(motion)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    func reset() {
        previousYaw = nil
        DispatchQueue.main.async { self.captureCount = 0 }
    }

    private func handleMotionUpdate(_ motion: CMDeviceMotion) {
        // ヨー角を度に変換（垂直軸まわりの回転 = 水平パン）
        let yaw = motion.attitude.yaw * (180.0 / .pi)

        guard let lastYaw = previousYaw else {
            previousYaw = yaw
            return
        }

        // ラップアラウンドを考慮した差分（-180〜180度に正規化）
        var delta = yaw - lastYaw
        while delta > 180  { delta -= 360 }
        while delta < -180 { delta += 360 }

        if abs(delta) >= captureAngle {
            previousYaw = yaw
            DispatchQueue.main.async {
                self.captureCount += 1
                self.onCapture?()
            }
        }
    }
}
