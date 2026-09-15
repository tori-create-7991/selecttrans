import SwiftUI

struct TTSHistoryView: View {
    @ObservedObject private var store = TTSHistoryStore.shared

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        Group {
            if store.entries.isEmpty {
                VStack {
                    Spacer()
                    Text("読み上げ履歴はまだありません")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(store.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.repo.isEmpty ? "(repo未指定)" : entry.repo)
                                .font(.headline)
                            if !entry.session.isEmpty {
                                Text(entry.session)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(Self.timeFormatter.string(from: entry.timestamp))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(entry.text)
                            .font(.body)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(width: 420, height: 360)
    }
}
