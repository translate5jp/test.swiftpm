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
        let newFraction = CGFloat(min(captureAngle / hFOV, 1.0))

        let h = images.map(\.size.height).min() ?? images[0].size.height
        let w = images[0].size.width
        let extraWidth = w * newFraction * CGFloat(images.count - 1)
        let totalWidth = w + extraWidth

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: totalWidth, height: h)
        )

        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // 最初のフレームは全幅で描画
            images[0].draw(in: CGRect(x: 0, y: 0, width: w, height: h))

            var x: CGFloat = w
            for img in images.dropFirst() {
                let addW = w * newFraction            // 今回描画する幅
                let skipX = w * (1.0 - newFraction)  // フレーム左端の重複部分

                // 追加領域だけクリッピングして描画
                cgCtx.saveGState()
                cgCtx.clip(to: CGRect(x: x, y: 0, width: addW, height: h))
                img.draw(in: CGRect(x: x - skipX, y: 0, width: w, height: h))
                cgCtx.restoreGState()

                x += addW
            }
        }
    }
}
