import Foundation

// MARK: - 1フライト分の記録

struct FlightRecord: Identifiable {
    var id = UUID()
    /// logbookColumns[i].id に対応するセル文字列
    var cells: [String]

    init(row: [String] = []) {
        let count = logbookColumns.count
        var c = Array(repeating: "", count: count)
        for i in 0..<min(row.count, count) {
            c[i] = Self.cleanOCRText(row[i], column: logbookColumns[i])
        }
        cells = c
    }

    subscript(columnId: Int) -> String {
        get { cells.indices.contains(columnId) ? cells[columnId] : "" }
        set { if cells.indices.contains(columnId) { cells[columnId] = newValue } }
    }

    /// 数値列に1つでも正の値があれば true（ヘッダー行除外に使用）
    var hasAnyNumericValue: Bool {
        logbookColumns
            .filter(\.isNumeric)
            .contains { FlightRecord.parseHours(cells[$0.id]) > 0 }
    }

    // MARK: 数値パース（小数時間 or HH:MM 両対応）

    static func parseHours(_ text: String) -> Double {
        let t = text.trimmingCharacters(in: .whitespaces)
        if let v = Double(t) { return v }
        let parts = t.split(separator: ":")
        if parts.count == 2,
           let hours = Double(parts[0]),
           let minutes = Double(parts[1]) {
            return hours + minutes / 60.0
        }
        return 0
    }

    // MARK: 合計値の表示フォーマット

    static func formatTotal(_ value: Double, isTime: Bool) -> String {
        guard value > 0 else { return "—" }
        if isTime {
            let hours = Int(value)
            let minutes = Int((value - Double(hours)) * 60 + 0.5)
            return String(format: "%d:%02d", hours, minutes)
        }
        return value == value.rounded(.towardZero) ? "\(Int(value))" : String(format: "%.1f", value)
    }

    // MARK: 数値列の OCR 誤認識補正（O→0、I→1 など）

    private static func cleanOCRText(_ text: String, column: LogbookColumn) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard column.isNumeric else { return trimmed }
        return trimmed
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
