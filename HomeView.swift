import SwiftUI

struct HomeView: View {
    @State private var sessions: [LogbookSession] = []
    @State private var showScan = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("ログブック")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showScan = true
                    } label: {
                        Label("スキャン", systemImage: "camera.fill")
                    }
                }
            }
            .sheet(isPresented: $showScan) {
                ScanView { session in
                    sessions.insert(session, at: 0)
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("ログブックをスキャン", systemImage: "doc.text.viewfinder")
        } description: {
            Text("カメラでログブックを撮影すると\n手書き文字を認識して飛行時間を集計します")
        } actions: {
            Button("スキャン開始") { showScan = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var sessionList: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink(destination: ResultView(session: session)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.formattedDate)
                            .font(.headline)
                        Text("\(session.rows.count) 行・\(session.columnCount) 列を認識")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { sessions.remove(atOffsets: $0) }
        }
    }
}
