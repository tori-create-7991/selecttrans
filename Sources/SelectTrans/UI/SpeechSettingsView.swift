import SwiftUI

struct SpeechSettingsView: View {
    private let preferences: TTSPreferenceStore
    @ObservedObject private var server = TTSServer.shared

    @State private var character: TTSCharacter
    @State private var rate: Float
    @State private var volume: Float
    @State private var pitch: Float
    @State private var cjkThreshold: Double
    @State private var languageMode: TTSLanguageMode
    @State private var speakRepoPrefix: Bool
    @State private var isMuted: Bool
    @State private var maxCharacters: Int
    @State private var isServerEnabled: Bool

    init() {
        let preferences = TTSPreferenceStore()
        self.preferences = preferences
        _isServerEnabled = State(initialValue: preferences.isServerEnabled)
        _character = State(initialValue: preferences.character)
        _rate = State(initialValue: preferences.rate)
        _volume = State(initialValue: preferences.volume)
        _pitch = State(initialValue: preferences.pitch)
        _cjkThreshold = State(initialValue: preferences.cjkThreshold)
        _languageMode = State(initialValue: preferences.languageMode)
        _speakRepoPrefix = State(initialValue: preferences.speakRepoPrefix)
        _isMuted = State(initialValue: preferences.isMuted)
        _maxCharacters = State(initialValue: preferences.maxCharacters)
    }

    var body: some View {
        Form {
            Section("ローカル読み上げサーバー") {
                Toggle("サーバーを有効にする", isOn: $isServerEnabled)
                    .onChange(of: isServerEnabled) { _, value in
                        preferences.isServerEnabled = value
                        if value {
                            TTSServer.shared.start()
                        } else {
                            TTSServer.shared.stop()
                        }
                    }
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(server.boundPort != nil ? .green : .secondary)
                Text("外部ツール（Claude Code Stop hookなど）からの読み上げリクエストを127.0.0.1でのみ受け付けます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("音声") {
                Toggle("読み上げをミュート", isOn: $isMuted)
                    .onChange(of: isMuted) { _, value in preferences.isMuted = value }
                Picker("キャラクター:", selection: $character) {
                    ForEach(TTSCharacter.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: character) { _, value in preferences.character = value }
                Text("日本語/英語のペア音声（Eddy/Flo/Grandma/Grandpa/Reed/Rocko/Sandy/Shelley）は言語が切り替わっても同じキャラで読み上げます。")
                    .font(.caption).foregroundStyle(.secondary)

                LabeledContent("速度") {
                    Slider(value: $rate, in: 0.3...0.7) { Text("速度") }
                        .onChange(of: rate) { _, value in preferences.rate = value }
                }
                LabeledContent("音量") {
                    Slider(value: $volume, in: 0...1) { Text("音量") }
                        .onChange(of: volume) { _, value in preferences.volume = value }
                }
                LabeledContent("ピッチ") {
                    Slider(value: $pitch, in: 0.5...2.0) { Text("ピッチ") }
                        .onChange(of: pitch) { _, value in preferences.pitch = value }
                }
            }

            Section("読み上げ言語") {
                Picker("判定方法:", selection: $languageMode) {
                    ForEach(TTSLanguageMode.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: languageMode) { _, value in preferences.languageMode = value }

                if languageMode == .auto {
                    LabeledContent("CJK比率のしきい値: \(Int(cjkThreshold * 100))%") {
                        Slider(value: $cjkThreshold, in: 0.0...0.5) { Text("しきい値") }
                            .onChange(of: cjkThreshold) { _, value in preferences.cjkThreshold = value }
                    }
                    Text("本文のCJK文字比率がこの値以上なら日本語、未満なら英語の音声で読み上げます。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("読み上げ内容") {
                Toggle("repo名を前置きして読み上げる", isOn: $speakRepoPrefix)
                    .onChange(of: speakRepoPrefix) { _, value in preferences.speakRepoPrefix = value }

                Stepper(value: $maxCharacters, in: 0...20000, step: 500) {
                    Text(maxCharacters == 0 ? "文字数上限: なし" : "文字数上限: \(maxCharacters)文字")
                }
                .onChange(of: maxCharacters) { _, value in preferences.maxCharacters = value }
                Text("上限を超えた本文は末尾を切り捨てて読み上げます（0で無制限）。長文で読み終わらない場合はここで短くするか、速度を上げてください。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("読み上げ中ポップアップ") {
                Text("ポップアップは背景をドラッグして好きな位置に移動できます。位置は次回以降も記憶されます。")
                    .font(.caption).foregroundStyle(.secondary)
                Button("位置を初期値（画面右下）に戻す") { preferences.popupOrigin = nil }
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    private var statusText: String {
        if let boundPort = server.boundPort {
            "起動中 — 127.0.0.1:\(boundPort)"
        } else {
            "停止中"
        }
    }
}
