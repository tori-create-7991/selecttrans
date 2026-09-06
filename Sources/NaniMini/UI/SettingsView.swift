import AppKit
import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @State private var translateModel = ModelStore.model(for: .translate)
    @State private var proofreadModel = ModelStore.model(for: .proofread)
    @State private var fastLiteralDisplay = TranslationPreferenceStore().isFastLiteralDisplayEnabled
    @State private var geminiKey = KeychainStore.get(.geminiAPIKey) ?? ""
    @State private var engine = TranslationEngineStore().selected
    @State private var modelPath = LocalModelStore().qwenModelURL?.path ?? "未設定"
    @State private var savedAt: Date?
    @State private var foundationModelStatus = "確認中…"
    @State private var qwenModelStatus = "確認中…"
    @StateObject private var qwenDownloader = QwenModelDownloader()

    var body: some View {
        Form {
            Section("ショートカット") {
                KeyboardShortcuts.Recorder("翻訳を起動:", name: .translate)
                KeyboardShortcuts.Recorder("スクショ翻訳:", name: .translateCapture)
            }
            Section("翻訳エンジン") {
                Picker("使用するエンジン:", selection: $engine) {
                    ForEach(TranslationEngineID.allCases) { Text($0.displayName).tag($0) }
                }
                Text(engine.usesNetworkForTranslation ? "Gemini翻訳はネットワークを使用します。" : "翻訳時はネットワークを使用しません。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if engine == .gemini {
                Section("Gemini") {
                    SecureField("API Key", text: $geminiKey)
                    Picker("翻訳:", selection: $translateModel) { ForEach(Config.availableModels, id: \.self) { Text($0).tag($0) } }
                    Picker("添削:", selection: $proofreadModel) { ForEach(Config.availableModels, id: \.self) { Text($0).tag($0) } }
                }
            }
            Section("翻訳の表示") {
                Toggle("直訳を先に表示", isOn: $fastLiteralDisplay)
                Text("ONでは直訳を先に表示し、その後に解説を追記します。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if engine == .qwenMLX {
                Section("Qwen 1.5B MLX") {
                    Text("約869MB。ダウンロード時だけHugging Faceへ接続し、翻訳時は完全にローカルです。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(modelPath).font(.caption).textSelection(.enabled)
                    Text(qwenModelStatus).font(.caption)
                        .foregroundStyle(qwenModelStatus == "利用できます" ? .green : .secondary)
                    HStack {
                        Button("Qwenをダウンロード") { qwenDownloader.download() }
                            .disabled(qwenIsDownloading)
                        Button("フォルダを選択", action: chooseModelFolder)
                            .disabled(qwenIsDownloading)
                    }
                    downloadState
                }
            }
            if engine == .foundationModels {
                Section("Apple Foundation Models") {
                    Text("Apple Intelligenceが有効で、システムモデルの準備完了時に利用できます。翻訳は端末上で実行します。")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(foundationModelStatus).font(.caption)
                        .foregroundStyle(foundationModelStatus == "利用できます" ? .green : .secondary)
                }
            }
            Section("履歴") {
                Text("翻訳履歴は端末のApplication Support内にMarkdownで保存されます。Notionには送信しません。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("履歴フォルダを開く", action: openHistoryFolder)
            }
            HStack {
                Spacer()
                if savedAt != nil { Text("保存しました").font(.caption).foregroundStyle(.green) }
                Button("保存", action: save).keyboardShortcut(.defaultAction)
            }
        }
        .padding(20).frame(width: 520)
        .task {
            await refreshFoundationModelStatus()
            await refreshQwenModelStatus()
        }
        .onChange(of: qwenDownloader.state) { _, _ in Task { await refreshQwenModelStatus() } }
    }

    @ViewBuilder private var downloadState: some View {
        switch qwenDownloader.state {
        case .idle: EmptyView()
        case .downloading(let file, let index, let total):
            ProgressView("ダウンロード中 (\(index)/\(total)): \(file)")
                .controlSize(.small)
        case .ready: Text("Qwenモデルを準備しました。保存を押して有効化してください。").font(.caption).foregroundStyle(.green)
        case .failed(let message): Text(message).font(.caption).foregroundStyle(.red)
        }
    }

    private func chooseModelFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? LocalModelStore().setQwenModelURL(url)
        modelPath = url.path
        Task { await refreshQwenModelStatus() }
    }

    private var qwenIsDownloading: Bool {
        if case .downloading = qwenDownloader.state { return true }
        return false
    }

    private func openHistoryFolder() {
        let directory = MarkdownHistoryStore.defaultDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    private func save() {
        ModelStore.set(translateModel, for: .translate); ModelStore.set(proofreadModel, for: .proofread)
        TranslationEngineStore().selected = engine
        TranslationPreferenceStore().isFastLiteralDisplayEnabled = fastLiteralDisplay
        KeychainStore.set(geminiKey, for: .geminiAPIKey)
        modelPath = LocalModelStore().qwenModelURL?.path ?? "未設定"; savedAt = Date()
    }

    private func refreshFoundationModelStatus() async {
        let availability = await FoundationModelsTranslationEngine().availability()
        foundationModelStatus = availability.isAvailable ? "利用できます" : (availability.reason ?? "利用できません")
    }

    private func refreshQwenModelStatus() async {
        let availability = await QwenMLXTranslationEngine().availability()
        qwenModelStatus = availability.isAvailable ? "利用できます" : (availability.reason ?? "利用できません")
    }
}
