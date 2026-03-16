import SwiftUI
import UIKit

struct ScanView: View {
    let onComplete: (LogbookSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isShowingImagePicker = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .camera
    @State private var isShowingPanoramicScan = false
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private let ocr = OCRService()
    private var isCameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Spacer()

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 90))
                    .foregroundStyle(.blue)

                VStack(spacing: 8) {
                    Text("ログブックページをスキャン")
                        .font(.title2.bold())
                    Text("手書き文字を認識して各列の合計値を自動計算します")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5)
                        Text("手書き文字を認識中…")
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 100)
                } else {
                    VStack(spacing: 12) {
                        // ── パノラマスキャン（横長ページ対応）──
                        if isCameraAvailable {
                            Button {
                                isShowingPanoramicScan = true
                            } label: {
                                VStack(spacing: 4) {
                                    Label("パノラマスキャン", systemImage: "camera.viewfinder")
                                        .font(.headline)
                                    Text("カメラを横に動かして広いページを撮影")
                                        .font(.caption)
                                        .opacity(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }

                        // ── 通常スキャン ──
                        if isCameraAvailable {
                            Button {
                                imagePickerSourceType = .camera
                                isShowingImagePicker = true
                            } label: {
                                Label("カメラで1枚撮影", systemImage: "camera")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }

                        Button {
                            imagePickerSourceType = .photoLibrary
                            isShowingImagePicker = true
                        } label: {
                            Label("フォトライブラリから選択", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 32)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("スキャン")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingImagePicker) {
                ImagePicker(sourceType: imagePickerSourceType) { image in
                    Task { await runOCR(on: image) }
                }
            }
            .fullScreenCover(isPresented: $isShowingPanoramicScan) {
                PanoramicScanView { session in
                    // PanoramicScanView が自身を dismiss した後、ここで ScanView も閉じる
                    onComplete(session)
                    dismiss()
                }
            }
        }
    }

    private func runOCR(on image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        let rows = await ocr.recognize(image: image)
        isProcessing = false
        if rows.isEmpty {
            errorMessage = "文字を認識できませんでした。\n明るい場所でページ全体が写るように撮影してください。"
        } else {
            onComplete(LogbookSession(rows: rows))
            dismiss()
        }
    }
}
