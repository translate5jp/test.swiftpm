import Vision
import UIKit

struct OCRService {

    /// 画像からテキストを認識し、JCAB列数(14)に揃えた行×列の二次元配列を返す
    func recognizeText(in image: UIImage) async -> [[String]] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                guard let results = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: Self.groupIntoRows(results))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP", "en-US"]
            // 数値・機体記号の誤補正を防ぐ
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.008  // 小さな文字も拾う

            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }

    // MARK: - 行グループ化 → 列マッピング

    private static func groupIntoRows(_ observations: [VNRecognizedTextObservation]) -> [[String]] {
        // 上から順に並べる（Vision 座標系は左下原点）
        let topToBottom = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        guard !topToBottom.isEmpty else { return [] }

        // Step1: Y 座標でグループ化（行の平均 Y と比較して安定させる）
        var rowGroups: [[VNRecognizedTextObservation]] = []
        var currentRow: [VNRecognizedTextObservation] = [topToBottom[0]]

        for obs in topToBottom.dropFirst() {
            let avgY = currentRow.map(\.boundingBox.midY).reduce(0, +) / CGFloat(currentRow.count)
            let avgH = currentRow.map(\.boundingBox.height).reduce(0, +) / CGFloat(currentRow.count)
            let threshold = max(avgH * 0.8, 0.015)  // 最低閾値を設けてノイズ耐性を上げる

            if abs(obs.boundingBox.midY - avgY) < threshold {
                currentRow.append(obs)
            } else {
                rowGroups.append(currentRow.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
                currentRow = [obs]
            }
        }
        rowGroups.append(currentRow.sorted { $0.boundingBox.minX < $1.boundingBox.minX })

        // Step2: 最多アイテム行を基準に列センターを決定
        guard let referenceRow = rowGroups.max(by: { $0.count < $1.count }),
              referenceRow.count >= 4 else {
            // フォールバック: そのまま文字列に変換
            return rowGroups.map { $0.compactMap { $0.topCandidates(1).first?.string } }
        }

        let columnCenters = referenceRow.map { $0.boundingBox.midX }

        // Step3: 全行を列センターにマッピング
        let columnCount = logbookColumns.count
        return rowGroups.map { row in
            mapObservationsToColumns(row, centers: columnCenters, targetCount: columnCount)
        }
    }

    /// 観測群を列センター配列に対応させ、空セルを "" で埋めた配列を返す
    private static func mapObservationsToColumns(
        _ row: [VNRecognizedTextObservation],
        centers: [CGFloat],
        targetCount: Int
    ) -> [String] {
        var result = Array(repeating: "", count: max(centers.count, targetCount))

        for obs in row {
            guard let text = obs.topCandidates(1).first?.string, !text.isEmpty else { continue }
            let midX = obs.boundingBox.midX

            // 最も近い列センターのインデックスを探す
            if let nearest = centers.enumerated().min(by: {
                abs($0.element - midX) < abs($1.element - midX)
            }) {
                let idx = nearest.offset
                if result.indices.contains(idx) {
                    // 同一列に複数要素が来た場合はスペースで結合
                    result[idx] = result[idx].isEmpty ? text : result[idx] + " " + text
                }
            }
        }

        return result
    }
}
