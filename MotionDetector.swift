import CoreMotion
import Foundation

/// CMMotionManager を使って水平方向の回転を検出し、一定角度ごとに撮影をトリガーする
class MotionDetector: ObservableObject {
    @Published var frameCount: Int = 0

    private let manager = CMMotionManager()
    private var lastYaw: Double?

    /// フレーム間の角度（度）。この値ごとに `onCapture` が呼ばれる
    let captureAngle: Double = 12.0
    var onCapture: (() -> Void)?

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func start() {
        guard isAvailable else { return }
        lastYaw = nil
        manager.deviceMotionUpdateInterval = 1.0 / 30
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.process(motion)
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }

    func reset() {
        lastYaw = nil
        DispatchQueue.main.async { self.frameCount = 0 }
    }

    private func process(_ motion: CMDeviceMotion) {
        // ヨー角を度に変換（垂直軸まわりの回転 = 水平パン）
        let yaw = motion.attitude.yaw * (180.0 / .pi)

        guard let last = lastYaw else {
            lastYaw = yaw
            return
        }

        // ラップアラウンドを考慮した差分（-180〜180度に正規化）
        var delta = yaw - last
        while delta > 180  { delta -= 360 }
        while delta < -180 { delta += 360 }

        if abs(delta) >= captureAngle {
            lastYaw = yaw
            DispatchQueue.main.async {
                self.frameCount += 1
                self.onCapture?()
            }
        }
    }
}
