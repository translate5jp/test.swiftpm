import UIKit

/// 複数フレームを水平方向に合成してパノラマ画像を生成する
struct ImageStitcher {

    /// - Parameters:
    ///   - images: 左から右の順に並んだキャプチャフレーム
    ///   - captureAngle: フレーム間の回転角度（度）
    ///   - hFOV: カメラの水平視野角（度）。標準広角カメラは約65°
    static func stitch(
        _ images: [UIImage],
        captureAngle: Double,
        hFOV: Double = 65.0
    ) -> UIImage? {
        guard !images.isEmpty else { return nil }
        guard images.count > 1 else { return images[0] }

        // 1フレームごとに追加される新規部分の割合（重複を除いた比率）
        let uniqueContentRatio = CGFloat(min(captureAngle / hFOV, 1.0))

        let frameHeight = images.map(\.size.height).min() ?? images[0].size.height
        let frameWidth = images[0].size.width
        let additionalWidth = frameWidth * uniqueContentRatio * CGFloat(images.count - 1)
        let totalWidth = frameWidth + additionalWidth

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: totalWidth, height: frameHeight)
        )

        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // 最初のフレームは全幅で描画
            images[0].draw(in: CGRect(x: 0, y: 0, width: frameWidth, height: frameHeight))

            var xOffset: CGFloat = frameWidth
            for img in images.dropFirst() {
                let newContentWidth = frameWidth * uniqueContentRatio  // 今回描画する幅
                let overlapOffset = frameWidth * (1.0 - uniqueContentRatio)  // フレーム左端の重複部分

                // 追加領域だけクリッピングして描画
                cgCtx.saveGState()
                cgCtx.clip(to: CGRect(x: xOffset, y: 0, width: newContentWidth, height: frameHeight))
                img.draw(in: CGRect(x: xOffset - overlapOffset, y: 0, width: frameWidth, height: frameHeight))
                cgCtx.restoreGState()

                xOffset += newContentWidth
            }
        }
    }
}
