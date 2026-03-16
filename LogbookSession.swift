import Foundation

struct LogbookSession: Identifiable {
    let id: UUID
    let date: Date
    var entries: [FlightEntry]

    init(rows: [[String]]) {
        id = UUID()
        date = Date()

        // 空行・ノイズ行を除外してエントリを生成
        // nonEmptyCount >= 3: 日付+出発地+目的地など最低3セルが埋まっていれば有効な行とみなす
        // hasAnyNumericValue のみで判定すると、手書き数字のOCR失敗で全行除外される恐れがある
        entries = rows
            .filter { !$0.isEmpty }
            .map { FlightEntry(row: $0) }
            .filter { $0.nonEmptyCount >= 3 }
    }

    var formattedScanDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "ja_JP")
        return f.string(from: date)
    }
}
