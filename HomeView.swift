import SwiftUI

struct HomeView: View {
    @State private var sessions: [LogbookSession] = []
    @State private var isScanPresented = false

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyPlaceholder
                } else {
                    scannedSessionList
                }
            }
            .navigationTitle("ログブック")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isScanPresented = true
                    } label: {
                        Label("スキャン", systemImage: "camera.fill")
                    }
                }
            }
            .sheet(isPresented: $isScanPresented) {
                ScanView { session in
                    sessions.insert(session, at: 0)
                }
            }
        }
    }

    private var emptyPlaceholder: some View {
        ContentUnavailableView {
            Label("ログブックをスキャン", systemImage: "doc.text.viewfinder")
        } description: {
            Text("カメラでログブックを撮影すると\n手書き文字を認識して飛行時間を集計します")
        } actions: {
            Button("スキャン開始") { isScanPresented = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var scannedSessionList: some View {
        List {
            ForEach(sessions) { session in
                NavigationLink(destination: ResultView(session: session)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.formattedScanDate)
                            .font(.headline)
                        Text("\(session.entries.count) フライト認識済み")
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
