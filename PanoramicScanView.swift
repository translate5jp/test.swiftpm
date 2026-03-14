import SwiftUI
import UIKit

/// カメラを横方向に動かしながらログブックをスキャンするビュー
struct PanoramicScanView: View {
    let onComplete: (LogbookSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraSession = CameraSession()
    @StateObject private var motionDetector = MotionDetector()

    @State private var isScanning = false
    @State private var isProcessing = false
    @State private var isCameraAccessDenied = false

    private let ocrService = OCRService()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraSession.isAuthorized {
                CameraPreviewView(session: cameraSession.captureSession)
                    .ignoresSafeArea()
            }

            // オーバーレイ UI
            VStack(spacing: 0) {
                topOverlay
                    .padding()

                Spacer()

                if isProcessing {
                    processingOverlay
                        .padding(.bottom, 48)
                } else {
                    scanControls
                        .padding(.horizontal)
                        .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            Task { await setupCameraSession() }
        }
        .onDisappear {
            motionDetector.stop()
            cameraSession.stop()
        }
        .alert("カメラへのアクセスが必要です", isPresented: $isCameraAccessDenied) {
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

    private var topOverlay: some View {
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
            ForEach(Array(cameraSession.capturedFrames.enumerated()), id: \.offset) { _, img in
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
        .animation(.spring, value: cameraSession.capturedFrames.count)
    }

    private var scanControls: some View {
        VStack(spacing: 16) {
            // ガイドメッセージ
            scanProgressGuide

            // ボタン行
            if !isScanning {
                Button {
                    beginScanning()
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
                if !motionDetector.isAvailable {
                    Button {
                        cameraSession.captureFrame()
                    } label: {
                        Label("フレームを撮影", systemImage: "camera.shutter.button")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .controlSize(.large)
                }

                if !cameraSession.capturedFrames.isEmpty {
                    Button {
                        finalizeScanning()
                    } label: {
                        Label("スキャン完了 (\(cameraSession.capturedFrames.count) フレーム)", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
    }

    private var scanProgressGuide: some View {
        Group {
            if !isScanning {
                EmptyView()
            } else if cameraSession.capturedFrames.isEmpty {
                scanGuidePill(text: "カメラをゆっくり右へ移動してください →", icon: "arrow.right")
            } else {
                scanGuidePill(text: "\(cameraSession.capturedFrames.count) フレーム撮影済み — 右へ続けて移動", icon: "arrow.right")
            }
        }
    }

    private func scanGuidePill(text: String, icon: String) -> some View {
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

    private func setupCameraSession() async {
        await cameraSession.setup()
        if cameraSession.isAuthorized {
            cameraSession.start()
        } else {
            isCameraAccessDenied = true
        }
    }

    private func beginScanning() {
        isScanning = true
        // 開始時に最初のフレームをすぐ撮影
        cameraSession.captureFrame()

        if motionDetector.isAvailable {
            motionDetector.onCapture = { cameraSession.captureFrame() }
            motionDetector.start()
        }
    }

    private func finalizeScanning() {
        motionDetector.stop()
        isScanning = false
        isProcessing = true
        let frames = cameraSession.capturedFrames
        cameraSession.stop()

        Task {
            let stitchedImage = ImageStitcher.stitch(
                frames,
                captureAngle: motionDetector.captureAngle
            ) ?? frames.last ?? UIImage()

            let rows = await ocrService.recognizeText(in: stitchedImage)
            let session = LogbookSession(rows: rows)

            await MainActor.run {
                isProcessing = false
                onComplete(session)
                dismiss()
            }
        }
    }
}
