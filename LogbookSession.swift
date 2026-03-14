import Foundation

struct LogbookSession: Identifiable {
    let id: UUID
    let date: Date
    var entries: [FlightRecord]

    init(rows: [[String]]) {
        id = UUID()
        date = Date()

        // ヘッダー行（数値を一切含まない行）を除外してレコードを生成
        entries = rows
            .filter { !$0.isEmpty }
            .map { FlightRecord(row: $0) }
            .filter { $0.hasAnyNumericValue }
    }

    /// スキャン日時の表示用文字列
    var formattedScanDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
    }

    /// 指定列の合計値
    func total(forColumnId columnId: Int) -> Double {
        entries.reduce(0) { $0 + FlightRecord.parseHours($1[columnId]) }
    }
}
