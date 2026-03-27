import Foundation

struct LogbookSession: Identifiable {
    let id: UUID
    let date: Date
    var entries: [FlightEntry]

    init(rows: [[String]]) {
        id = UUID()
        date = Date()

        // ヘッダー行（数値を一切含まない行）を除外してエントリを生成
        entries = rows
            .filter { !$0.isEmpty }
            .map { FlightEntry(row: $0) }
            .filter { $0.hasAnyNumericValue }
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: date)
    }

    /// 指定列の合計値
    func sum(columnId: Int) -> Double {
        entries.reduce(0) { $0 + FlightEntry.parseNumeric($1[columnId]) }
    }
}
