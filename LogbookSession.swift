import Foundation

struct LogbookSession: Identifiable {
    let id: UUID
    let date: Date
    var rows: [[String]]

    init(rows: [[String]]) {
        self.id = UUID()
        self.date = Date()
        self.rows = rows
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: date)
    }

    var columnCount: Int {
        rows.map(\.count).max() ?? 0
    }

    /// 指定列の数値合計（時間形式 "1:30" も小数 "1.5" も対応）
    func sum(column: Int) -> Double {
        rows.reduce(0) { total, row in
            guard column < row.count else { return total }
            return total + Self.parseNumeric(row[column])
        }
    }

    /// 数値を含む列のインデックス集合
    var numericColumnIndices: IndexSet {
        var result = IndexSet()
        for row in rows {
            for (i, cell) in row.enumerated() {
                if Self.parseNumeric(cell) > 0 { result.insert(i) }
            }
        }
        return result
    }

    static func parseNumeric(_ s: String) -> Double {
        let t = s.trimmingCharacters(in: .whitespaces)
        if let v = Double(t) { return v }
        let parts = t.split(separator: ":")
        if parts.count == 2, let h = Double(parts[0]), let m = Double(parts[1]) {
            return h + m / 60.0
        }
        return 0
    }
}
