import Foundation

// MARK: - JCAB 標準列定義（航空法施行規則に基づく操縦士技能証明書携帯者用航空日誌）
//
// 航空法第70条及び航空法施行規則第65条の規定により、操縦士は操縦した全フライトを
// 航空日誌に記録する義務がある。本フォーマットは国土交通省航空局（JCAB）が
// 標準とする以下14項目の列定義に準拠する。
//
// 列順（左→右）:
//  0 年月日   1 出発地   2 目的地   3 機種    4 機体記号
//  5 飛行時間 6 単独飛行 7 同乗飛行 8 機長時間 9 計器飛行
// 10 夜間飛行 11 離陸回数 12 着陸回数 13 備考

struct LogbookColumn: Identifiable {
    let id: Int
    let header: String       // 正式名（航空日誌の列ヘッダー）
    let shortHeader: String  // テーブル表示用短縮名
    let minWidth: CGFloat
    let isNumeric: Bool      // 合計対象の数値列か
    let isTime: Bool         // 飛行時間（小数 or HH:MM）形式か
}

let logbookColumns: [LogbookColumn] = [
    // ── 識別情報（非数値）──────────────────────────────────────────────
    LogbookColumn(id: 0,  header: "年月日",   shortHeader: "日付",  minWidth: 76, isNumeric: false, isTime: false),
    LogbookColumn(id: 1,  header: "出発地",   shortHeader: "出発",  minWidth: 62, isNumeric: false, isTime: false),
    LogbookColumn(id: 2,  header: "目的地",   shortHeader: "目的",  minWidth: 62, isNumeric: false, isTime: false),
    LogbookColumn(id: 3,  header: "機種",     shortHeader: "機種",  minWidth: 62, isNumeric: false, isTime: false),
    LogbookColumn(id: 4,  header: "機体記号", shortHeader: "機体",  minWidth: 68, isNumeric: false, isTime: false),

    // ── 飛行時間（小数 or HH:MM、合計対象）─────────────────────────────
    LogbookColumn(id: 5,  header: "飛行時間", shortHeader: "合計",  minWidth: 52, isNumeric: true,  isTime: true),
    LogbookColumn(id: 6,  header: "単独飛行", shortHeader: "単独",  minWidth: 52, isNumeric: true,  isTime: true),
    LogbookColumn(id: 7,  header: "同乗飛行", shortHeader: "同乗",  minWidth: 52, isNumeric: true,  isTime: true),
    LogbookColumn(id: 8,  header: "機長時間", shortHeader: "機長",  minWidth: 52, isNumeric: true,  isTime: true),
    LogbookColumn(id: 9,  header: "計器飛行", shortHeader: "計器",  minWidth: 52, isNumeric: true,  isTime: true),
    LogbookColumn(id: 10, header: "夜間飛行", shortHeader: "夜間",  minWidth: 52, isNumeric: true,  isTime: true),

    // ── 回数（整数カウント、合計対象）──────────────────────────────────
    LogbookColumn(id: 11, header: "離陸回数", shortHeader: "T/O",   minWidth: 44, isNumeric: true,  isTime: false),
    LogbookColumn(id: 12, header: "着陸回数", shortHeader: "Ldg",   minWidth: 44, isNumeric: true,  isTime: false),

    // ── 備考（非数値）──────────────────────────────────────────────────
    LogbookColumn(id: 13, header: "備考",     shortHeader: "備考",  minWidth: 90, isNumeric: false, isTime: false),
]
