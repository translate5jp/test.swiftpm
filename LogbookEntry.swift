import Foundation

// MARK: - JCAB 標準列定義（左→右の順）

struct LogbookColumn: Identifiable {
    let id: Int
    let header: String       // 正式名
    let shortHeader: String  // テーブルヘッダー短縮名
    let minWidth: CGFloat
    let isNumeric: Bool      // 合計対象の数値列か
    let isTime: Bool         // 飛行時間（小数 or HH:MM）形式か
}

let logbookColumns: [LogbookColumn] = [
    LogbookColumn(id: 0,  header: "Date",              shortHeader: "Date",   minWidth: 76,  isNumeric: false, isTime: false),
    LogbookColumn(id: 1,  header: "Departure",         shortHeader: "Dep",    minWidth: 62,  isNumeric: false, isTime: false),
    LogbookColumn(id: 2,  header: "Dep. Time",         shortHeader: "DepT",   minWidth: 56,  isNumeric: false, isTime: false),
    LogbookColumn(id: 3,  header: "Destination",       shortHeader: "Dest",   minWidth: 62,  isNumeric: false, isTime: false),
    LogbookColumn(id: 4,  header: "Arr. Time",         shortHeader: "ArrT",   minWidth: 56,  isNumeric: false, isTime: false),
    LogbookColumn(id: 5,  header: "Aircraft Type",     shortHeader: "Type",   minWidth: 62,  isNumeric: false, isTime: false),
    LogbookColumn(id: 6,  header: "Aircraft Reg.",     shortHeader: "Reg",    minWidth: 68,  isNumeric: false, isTime: false),
    LogbookColumn(id: 7,  header: "Total Time",        shortHeader: "Total",  minWidth: 52,  isNumeric: true,  isTime: true),
    LogbookColumn(id: 8,  header: "Solo",              shortHeader: "Solo",   minWidth: 52,  isNumeric: true,  isTime: true),
    LogbookColumn(id: 9,  header: "Dual",              shortHeader: "Dual",   minWidth: 52,  isNumeric: true,  isTime: true),
    LogbookColumn(id: 10, header: "PIC",               shortHeader: "PIC",    minWidth: 52,  isNumeric: true,  isTime: true),
    LogbookColumn(id: 11, header: "Cross Country PIC", shortHeader: "XC-PIC", minWidth: 60,  isNumeric: true,  isTime: true),
    LogbookColumn(id: 12, header: "Cross Country SIC", shortHeader: "XC-SIC", minWidth: 60,  isNumeric: true,  isTime: true),
    LogbookColumn(id: 13, header: "Instrument",        shortHeader: "Inst",   minWidth: 52,  isNumeric: true,  isTime: true),
    LogbookColumn(id: 14, header: "Night PIC",         shortHeader: "NtPIC",  minWidth: 52,  isNumeric: true,  isTime: true),
    LogbookColumn(id: 15, header: "Night SIC",         shortHeader: "NtSIC",  minWidth: 52,  isNumeric: true,  isTime: true),
    LogbookColumn(id: 16, header: "Takeoffs",          shortHeader: "T/O",    minWidth: 44,  isNumeric: true,  isTime: false),
    LogbookColumn(id: 17, header: "Landings",          shortHeader: "Ldg",    minWidth: 44,  isNumeric: true,  isTime: false),
    LogbookColumn(id: 18, header: "Remarks",           shortHeader: "Rmks",   minWidth: 100, isNumeric: false, isTime: false),
]

// MARK: - 1フライト分のエントリ

struct FlightEntry: Identifiable {
    var id = UUID()
    /// logbookColumns[i].id に対応するセル文字列
    var values: [String]

    init(row: [String] = []) {
        let count = logbookColumns.count
        var v = Array(repeating: "", count: count)
        for i in 0..<min(row.count, count) {
            v[i] = Self.sanitizeOCR(row[i], col: logbookColumns[i])
        }
        values = v
    }

    subscript(colId: Int) -> String {
        get { values.indices.contains(colId) ? values[colId] : "" }
        set { if values.indices.contains(colId) { values[colId] = newValue } }
    }

    /// 空でないセルの数（ノイズ行の除外に使用）
    var nonEmptyCount: Int {
        values.filter { !$0.isEmpty }.count
    }

    // MARK: 数値パース（小数 or HH:MM 両対応）

    static func parseNumeric(_ s: String) -> Double {
        let t = s.trimmingCharacters(in: .whitespaces)
        if let v = Double(t) { return v }
        let parts = t.split(separator: ":")
        if parts.count == 2,
           let h = Double(parts[0]),
           let m = Double(parts[1]) {
            return h + m / 60.0
        }
        return 0
    }

    // MARK: 列合計値の表示フォーマット

    static func formatTotal(_ value: Double, isTime: Bool) -> String {
        guard value > 0 else { return "—" }
        if isTime {
            let h = Int(value)
            let m = Int((value - Double(h)) * 60 + 0.5)
            return String(format: "%d:%02d", h, m)
        }
        return value == value.rounded(.towardZero) ? "\(Int(value))" : String(format: "%.1f", value)
    }

    // MARK: 数値列の OCR 誤認識を補正

    private static func sanitizeOCR(_ s: String, col: LogbookColumn) -> String {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard col.isNumeric else { return t }
        return t
            .replacingOccurrences(of: "O", with: "0")
            .replacingOccurrences(of: "o", with: "0")
            .replacingOccurrences(of: "Q", with: "0")
            .replacingOccurrences(of: "l", with: "1")
            .replacingOccurrences(of: "I", with: "1")
            .replacingOccurrences(of: "，", with: ".")
            .replacingOccurrences(of: "、", with: ".")
            .replacingOccurrences(of: "。", with: ".")
    }
}
