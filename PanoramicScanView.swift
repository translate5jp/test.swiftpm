import SwiftUI
import UIKit

/// カメラを横方向に動かしながらログブックをスキャンするビュー
struct PanoramicScanView: View {
    let onComplete: (LogbookSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraSession()
    @StateObject private var motion = MotionDetector()

    @State private var isScanning = false
    @State private var isProcessing = false
    @State private var isShowingCameraAccessAlert = false

    private let ocr = OCRService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if camera.isAuthorized {
                CameraPreviewView(session: camera.captureSession)
                    .ignoresSafeArea()
            }

            // オーバーレイ UI
            VStack(spacing: 0) {
                topBar
                    .padding()

                Spacer()

                if isProcessing {
                    processingOverlay
                        .padding(.bottom, 48)
                } else {
                    controlsPanel
                        .padding(.horizontal)
                        .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            Task { await setupCamera() }
        }
        .onDisappear {
            motion.stop()
            camera.stop()
        }
        .alert("カメラへのアクセスが必要です", isPresented: $isShowingCameraAccessAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("閉じる", role: .cancel) { dismiss() }
        } message: {
            Text("設定 › プライバシー › カメラ でアクセスを許可してください")
        }
    }

    // MARK: - サブビュー

    private var topBar: some View {
        HStack(alignment: .top) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.largeTitle)
                    .foregroundStyle(.white)
            }
            Spacer()
            capturedFrameThumbnails
        }
    }

    private var capturedFrameThumbnails: some View {
        HStack(spacing: 6) {
            ForEach(Array(camera.capturedFrames.enumerated()), id: \.offset) { i, img in
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.white.opacity(0.6), lineWidth: 1)
                    )
            }
        }
        .animation(.spring, value: camera.capturedFrames.count)
    }

    private var controlsPanel: some View {
        VStack(spacing: 16) {
            // ガイドメッセージ
            scanGuide

            // ボタン行
            if !isScanning {
                Button {
                    startScanning()
                } label: {
                    Label("スキャン開始", systemImage: "record.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text("カメラをログブックの\n左端に向けてからタップ")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                // モーション非対応端末ではマニュアル撮影ボタンを表示
                if !motion.isAvailable {
                    Button {
                        camera.captureFrame()
                    } label: {
                        Label("フレームを撮影", systemImage: "camera.shutter.button")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.large)
                }

                if !camera.capturedFrames.isEmpty {
                    Button {
                        finishScanning()
                    } label: {
                        Label("スキャン完了 (\(camera.capturedFrames.count) フレーム)", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
    }

    private var scanGuide: some View {
        Group {
            if !isScanning {
                EmptyView()
            } else if camera.capturedFrames.isEmpty {
                guidePill(text: "カメラをゆっくり右へ移動してください →", icon: "arrow.right")
            } else {
                guidePill(text: "\(camera.capturedFrames.count) フレーム撮影済み — 右へ続けて移動", icon: "arrow.right")
            }
        }
    }

    private func guidePill(text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.6), in: Capsule())
    }

    private var processingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)
            Text("画像を合成してOCR処理中…")
                .foregroundStyle(.white)
        }
    }

    // MARK: - ロジック

    private func setupCamera() async {
        await camera.setup()
        if camera.isAuthorized {
            camera.start()
        } else {
            isShowingCameraAccessAlert = true
        }
    }

    private func startScanning() {
        isScanning = true
        // 開始時に最初のフレームをすぐ撮影
        camera.captureFrame()

        if motion.isAvailable {
            motion.onCapture = { camera.captureFrame() }
            motion.start()
        }
    }

    private func finishScanning() {
        motion.stop()
        isScanning = false
        isProcessing = true
        let frames = camera.capturedFrames
        camera.stop()

        Task {
            let stitched = ImageStitcher.stitch(
                frames,
                captureAngle: motion.captureAngle
            ) ?? frames.last ?? UIImage()

            let rows = await ocr.recognize(image: stitched)
            let session = LogbookSession(rows: rows)

            await MainActor.run {
                isProcessing = false
                onComplete(session)
                dismiss()
            }
        }
    }
}
