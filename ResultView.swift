import SwiftUI

struct ResultView: View {
    let session: LogbookSession
    @State private var entries: [FlightEntry]

    init(session: LogbookSession) {
        self.session = session
        _entries = State(initialValue: session.entries)
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryBar
            Divider()
            if entries.isEmpty {
                emptyState
            } else {
                logbookTable
            }
        }
        .navigationTitle("認識結果")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 合計サマリーバー（数値列のみ）

    private var summaryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(logbookColumns.filter(\.isNumeric)) { col in
                    SummaryCard(
                        title: col.shortHeader,
                        rawValue: sum(col),
                        isTime: col.isTime
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - テーブル（縦横スクロール）

    private var logbookTable: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                ForEach(entries.indices, id: \.self) { i in
                    dataRow(index: i)
                    Divider().background(Color(.systemGray5))
                }
                totalsRow
            }
            .padding(8)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(logbookColumns) { col in
                Text(col.shortHeader)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: col.minWidth, height: 28, alignment: .center)
                    .background(Color.blue)
                    .border(Color.blue.opacity(0.4))
            }
        }
    }

    private func dataRow(index: Int) -> some View {
        let bg: Color = index.isMultiple(of: 2) ? .clear : Color(.systemGray6)
        return HStack(spacing: 0) {
            ForEach(logbookColumns) { col in
                TextField("", text: Binding(
                    get: { entries[index][col.id] },
                    set: { entries[index][col.id] = $0 }
                ))
                .font(.caption)
                .multilineTextAlignment(.center)
                .frame(width: col.minWidth, height: 32, alignment: .center)
                .background(bg)
                .border(Color(.systemGray5))
                // 数値列は軽くハイライト
                .background(
                    col.isNumeric && !entries[index][col.id].isEmpty
                    ? Color.blue.opacity(0.06)
                    : Color.clear
                )
            }
        }
    }

    private var totalsRow: some View {
        HStack(spacing: 0) {
            // 最初のセルに「合計」ラベル
            Text("合計")
                .font(.caption.bold())
                .frame(width: logbookColumns[0].minWidth, height: 32, alignment: .center)
                .background(Color.blue.opacity(0.15))
                .border(Color(.systemGray4))

            ForEach(logbookColumns.dropFirst()) { col in
                let s = sum(col)
                Text(FlightEntry.formatSum(s, isTime: col.isTime))
                    .font(.caption.bold())
                    .foregroundStyle(s > 0 ? Color.primary : Color.secondary)
                    .frame(width: col.minWidth, height: 32, alignment: .center)
                    .background(Color.blue.opacity(0.15))
                    .border(Color(.systemGray4))
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "エントリが認識できませんでした",
            systemImage: "text.slash",
            description: Text("明るい場所で表全体が写るように再スキャンしてください")
        )
    }

    // MARK: - ヘルパー

    private func sum(_ col: LogbookColumn) -> Double {
        entries.reduce(0) { $0 + FlightEntry.parseNumeric($1[col.id]) }
    }
}

// MARK: - サマリーカード

private struct SummaryCard: View {
    let title: String
    let rawValue: Double
    let isTime: Bool

    private var display: String {
        FlightEntry.formatSum(rawValue, isTime: isTime)
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(display == "—" ? (isTime ? "0:00" : "0") : display)
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(rawValue > 0 ? Color.primary : Color.secondary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
