import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @State private var translateModel = ModelStore.model(for: .translate)
    @State private var proofreadModel = ModelStore.model(for: .proofread)
    @State private var fastLiteralDisplay = TranslationPreferenceStore().isFastLiteralDisplayEnabled
    @State private var geminiKey = KeychainStore.get(.geminiAPIKey) ?? ""
    @State private var notionToken = KeychainStore.get(.notionToken) ?? ""
    @State private var notionDatabaseID = KeychainStore.get(.notionDatabaseID) ?? ""
    @State private var savedAt: Date?

    var body: some View {
        Form {
            Section("ショートカット") {
                KeyboardShortcuts.Recorder("翻訳を起動:", name: .translate)
                KeyboardShortcuts.Recorder("スクショ翻訳:", name: .translateCapture)
            }
            Section("Gemini モデル") {
                Picker("翻訳:", selection: $translateModel) {
                    ForEach(Config.availableModels, id: \.self) { Text($0).tag($0) }
                }
                Picker("添削:", selection: $proofreadModel) {
                    ForEach(Config.availableModels, id: \.self) { Text($0).tag($0) }
                }
            }
            Section("翻訳の表示") {
                Toggle("直訳を先に表示", isOn: $fastLiteralDisplay)
                Text("ONでは直訳を先に表示し、その後に解説を追記します。通常は翻訳ごとにGemini APIを2回使用し、一時的な失敗時は再試行します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section("Gemini") {
                SecureField("API Key", text: $geminiKey)
            }
            Section("Notion 履歴（任意）") {
                SecureField("Integration Token", text: $notionToken)
                TextField("Database ID", text: $notionDatabaseID)
            }
            HStack {
                Spacer()
                if savedAt != nil {
                    Text("保存しました").font(.caption).foregroundStyle(.green)
                }
                Button("保存", action: save).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 440)
    }

    private func save() {
        ModelStore.set(translateModel, for: .translate)
        ModelStore.set(proofreadModel, for: .proofread)
        TranslationPreferenceStore().isFastLiteralDisplayEnabled = fastLiteralDisplay
        KeychainStore.set(geminiKey, for: .geminiAPIKey)
        KeychainStore.set(notionToken, for: .notionToken)
        KeychainStore.set(notionDatabaseID, for: .notionDatabaseID)
        savedAt = Date()
    }
}
