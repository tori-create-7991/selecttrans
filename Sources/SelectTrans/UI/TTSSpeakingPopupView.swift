import SwiftUI

struct TTSSpeakingPopupView: View {
    let item: TTSSpeakingItem
    @State private var showsDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.secondary)
                Text(item.repo.isEmpty ? "読み上げ中…" : item.repo)
                    .font(.headline)
                Spacer()
            }
            Text(item.text)
                .font(.body)
                .lineLimit(5)
            HStack {
                Spacer()
                Button("詳細") { showsDetail = true }
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(width: 320)
        .sheet(isPresented: $showsDetail) {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.repo.isEmpty ? "読み上げ中" : item.repo)
                    .font(.headline)
                ScrollView {
                    Text(item.text)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                HStack {
                    Spacer()
                    Button("閉じる") { showsDetail = false }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 420, height: 320)
        }
    }
}
