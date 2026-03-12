import Vision
import UIKit

struct OCRService {

    /// 画像からテキストを認識し、行×列の二次元配列で返す
    func recognize(image: UIImage) async -> [[String]] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                guard let results = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: Self.groupByRows(results))
            }
            request.recognitionLevel = .accurate
            // 日本語と英語（数字含む）を対象とする
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.usesLanguageCorrection = false  // 数字の誤補正を防ぐ

            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }

    /// 認識結果をY座標でグループ化し、各行内をX座標でソート
    private static func groupByRows(_ observations: [VNRecognizedTextObservation]) -> [[String]] {
        // 上から順に並べる（Vision座標系は左下原点なので minY 降順）
        let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        guard !sorted.isEmpty else { return [] }

        var groups: [[VNRecognizedTextObservation]] = []
        var current: [VNRecognizedTextObservation] = [sorted[0]]

        for obs in sorted.dropFirst() {
            // 同一行と見なす閾値（バウンディングボックスの高さの半分程度）
            let threshold: CGFloat = current.last!.boundingBox.height * 0.6
            if abs(obs.boundingBox.midY - current.last!.boundingBox.midY) < threshold {
                current.append(obs)
            } else {
                groups.append(current.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
                current = [obs]
            }
        }
        groups.append(current.sorted { $0.boundingBox.minX < $1.boundingBox.minX })

        return groups.map { row in
            row.compactMap { $0.topCandidates(1).first?.string }
        }
    }
}
