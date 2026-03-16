import Vision
import UIKit
import CoreImage

struct OCRService {

    // MARK: - 画像前処理

    /// グレースケール化・コントラスト強調・シャープ化でOCR精度を向上させる
    private func preprocess(_ image: UIImage) -> UIImage {
        guard let ci = CIImage(image: image) else { return image }

        let filtered = ci
            .applyingFilter("CIPhotoEffectMono")                // グレースケール化
            .applyingFilter("CIColorControls", parameters: [
                kCIInputContrastKey: 1.5,                       // コントラスト強調
                kCIInputBrightnessKey: 0.05                     // 微増光で薄い手書きを補完
            ])
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 2.5,
                kCIInputIntensityKey: 0.8                       // エッジ強調でにじみを軽減
            ])

        // CIImage の extent は元画像の生座標系（回転適用前）で表される
        // createCGImage も同座標系で CGImage を生成するので orientation はそのまま引き継ぐ
        guard let cg = CIContext().createCGImage(filtered, from: filtered.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - OCR

    /// 画像からテキストを認識し、JCAB列数に揃えた行×列の二次元配列を返す
    func recognize(image: UIImage) async -> [[String]] {
        let processed = preprocess(image)
        guard let cgImage = processed.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                guard let results = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: Self.extractRows(results))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP", "en-US"]
            // 数値・機体記号の誤補正を防ぐ
            request.usesLanguageCorrection = false
            request.minimumTextHeight = 0.008
            // 空港コード・機種・用語を登録して誤認識を低減
            request.customWords = Self.customWords

            try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        }
    }

    // MARK: - カスタム語彙

    /// Vision が認識候補として優先する語彙リスト
    /// 空港 ICAO コード・機体記号プレフィックス・機種略称・ログブック用語を収録
    private static let customWords: [String] = [
        // 国内主要空港 ICAO コード
        "RJAA", "RJTT", "RJBB", "RJOO", "RJCC", "RJFF", "RJFU",
        "ROAH", "RJSN", "RJCH", "RJFK", "RJKA", "RJNK", "RJOA",
        "RJOB", "RJOC", "RJOH", "RJOS", "RJOW", "RJSA", "RJSK",
        "RJSS", "RJTA", "RJTO", "RJTJ", "RJTY", "RJNG", "RJNA",
        "RJCO", "RJCJ", "RJEC", "RJEO", "RJCM", "RJEO", "RJFE",
        // 機体記号プレフィックス
        "JA",
        // 機種略称（大型機）
        "B737", "B747", "B767", "B777", "B787",
        "A320", "A321", "A330", "A350", "A380",
        // 機種略称（小型機）
        "C172", "C182", "C208", "PA28", "PA44",
        "BE36", "BE58", "SR20", "SR22",
        // ログブック用語
        "VFR", "IFR", "NVFR",
        "PIC", "SIC", "DUAL", "SOLO",
        "T/O", "LDG",
    ]

    // MARK: - 行グループ化 → 列マッピング

    private static func extractRows(_ observations: [VNRecognizedTextObservation]) -> [[String]] {
        // 上から順に並べる（Vision 座標系は左下原点）
        let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        guard !sorted.isEmpty else { return [] }

        // Step1: Y 座標でグループ化（行の平均 Y と比較して安定させる）
        var rawGroups: [[VNRecognizedTextObservation]] = []
        var current: [VNRecognizedTextObservation] = [sorted[0]]

        for obs in sorted.dropFirst() {
            let avgY = current.map(\.boundingBox.midY).reduce(0, +) / CGFloat(current.count)
            let avgH = current.map(\.boundingBox.height).reduce(0, +) / CGFloat(current.count)
            // 閾値は行高の40%: 同一行内のY変動(±20〜30%)を吸収しつつ行間(50〜100%)では分離する
            let threshold = max(avgH * 0.4, 0.005)

            if abs(obs.boundingBox.midY - avgY) < threshold {
                current.append(obs)
            } else {
                rawGroups.append(current.sorted { $0.boundingBox.minX < $1.boundingBox.minX })
                current = [obs]
            }
        }
        rawGroups.append(current.sorted { $0.boundingBox.minX < $1.boundingBox.minX })

        // Step2: 最多アイテム行を基準に列センターを決定
        guard let refRow = rawGroups.max(by: { $0.count < $1.count }),
              refRow.count >= 4 else {
            // フォールバック: そのまま文字列に変換
            return rawGroups.map { $0.compactMap { $0.topCandidates(1).first?.string } }
        }

        let colCenters = refRow.map { $0.boundingBox.midX }

        // Step3: 全行を列センターにマッピング
        let colCount = logbookColumns.count
        return rawGroups.map { row in
            mapToColumns(row, centers: colCenters, targetCount: colCount)
        }
    }

    /// 観測群を列センター配列に対応させ、空セルを "" で埋めた配列を返す
    private static func mapToColumns(
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
