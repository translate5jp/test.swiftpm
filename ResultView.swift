import SwiftUI

struct ResultView: View {
    let session: LogbookSession

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if session.rows.isEmpty {
                ContentUnavailableView(
                    "認識結果なし",
                    systemImage: "text.slash",
                    description: Text("テキストが認識されませんでした")
                )
                .padding()
            } else {
                LogbookTable(session: session)
                    .padding()
            }
        }
        .navigationTitle("認識結果")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Table

private struct LogbookTable: View {
    let session: LogbookSession

    private var colCount: Int { session.columnCount }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // データ行
            ForEach(Array(session.rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(0..<colCount, id: \.self) { col in
                        TableCell(
                            text: col < row.count ? row[col] : "",
                            style: .data
                        )
                    }
                }
                Divider()
            }

            // 合計行
            HStack(spacing: 0) {
                TableCell(text: "合計", style: .total)
                ForEach(1..<colCount, id: \.self) { col in
                    let sum = session.sum(column: col)
                    TableCell(
                        text: sum > 0 ? formatSum(sum, column: col) : "—",
                        style: .total
                    )
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    private func formatSum(_ value: Double, column: Int) -> String {
        // 整数に近い場合は整数表示（離着陸回数など）
        if value == value.rounded() && value < 1000 {
            let allInts = session.rows.allSatisfy { row in
                guard column < row.count else { return true }
                let s = row[column]
                return Double(s) == Double(s)?.rounded() || s.isEmpty
            }
            if allInts { return String(Int(value)) }
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Cell

private struct TableCell: View {
    let text: String
    let style: CellStyle

    enum CellStyle { case data, total }

    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(style == .total ? .caption.bold() : .caption)
            .foregroundStyle(style == .total ? Color.primary : Color.primary)
            .frame(minWidth: 64, alignment: .center)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(style == .total ? Color.blue.opacity(0.12) : Color.clear)
            .border(Color(.systemGray5))
    }
}
