import SwiftUI
import UIKit

struct ScanView: View {
    let onComplete: (LogbookSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private let ocr = OCRService()
    private var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

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
                    Text("手書き文字を認識して\n各列の合計値を自動計算します")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("手書き文字を認識中...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 100)
                } else {
                    VStack(spacing: 12) {
                        if cameraAvailable {
                            actionButton(
                                title: "カメラで撮影",
                                icon: "camera.fill",
                                style: .borderedProminent
                            ) {
                                sourceType = .camera
                                showPicker = true
                            }
                        }

                        actionButton(
                            title: "フォトライブラリから選択",
                            icon: "photo.on.rectangle",
                            style: .bordered
                        ) {
                            sourceType = .photoLibrary
                            showPicker = true
                        }
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
            .sheet(isPresented: $showPicker) {
                ImagePicker(sourceType: sourceType) { image in
                    Task { await process(image) }
                }
            }
        }
    }

    @ViewBuilder
    private func actionButton(
        title: String,
        icon: String,
        style: some PrimitiveButtonStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(style)
        .controlSize(.large)
    }

    private func process(_ image: UIImage) async {
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
