import SwiftUI
import AppKit

@MainActor
final class PopupModel: ObservableObject {
    @Published var source = ""
    @Published var output = ""
    @Published var direction = ""
    @Published var mode: TranslationMode = .translate
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// BCP-47 language of `output`, used for TTS voice selection.
    @Published var outputLanguage = "en-US"
    @Published var backTranslation: String?
    @Published var isBackTranslating = false
}

struct PopupView: View {
    @ObservedObject var model: PopupModel
    var onModeChange: (TranslationMode) -> Void
    var onTranslate: () -> Void
    var onBackTranslate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(model.direction.isEmpty ? "EN ⇄ JA" : model.direction)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: Binding(
                    get: { model.mode },
                    set: { onModeChange($0) }
                )) {
                    ForEach(TranslationMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .labelsHidden()
            }

            // MARK: Source (editable)
            Text("原文").font(.caption2).foregroundStyle(.secondary)
            editor(text: $model.source, minHeight: 70)
            HStack {
                Spacer()
                Button("翻訳", action: onTranslate)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Divider()

            // MARK: Output (editable)
            Text("訳文").font(.caption2).foregroundStyle(.secondary)
            ZStack(alignment: .center) {
                editor(text: $model.output, minHeight: 100)
                if model.isLoading && model.output.isEmpty {
                    ProgressView()
                }
            }

            if let error = model.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // MARK: Back-translation
            if model.isBackTranslating {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("逆翻訳中…").font(.caption).foregroundStyle(.secondary)
                }
            } else if let back = model.backTranslation {
                Text("🔁 \(back)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // MARK: Actions
            HStack(spacing: 8) {
                Spacer()
                Button {
                    Speaker.shared.speak(model.output, language: model.outputLanguage)
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .help("発音")
                .disabled(model.output.isEmpty)

                Button("逆翻訳", action: onBackTranslate)
                    .disabled(model.output.isEmpty || model.isBackTranslating)

                Button("コピー", action: copyOutput)
                    .disabled(model.output.isEmpty)
            }
        }
        .padding(14)
        .frame(width: 440, height: 470)
    }

    private func editor(text: Binding<String>, minHeight: CGFloat) -> some View {
        TextEditor(text: text)
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(minHeight: minHeight, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func copyOutput() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.output, forType: .string)
    }
}
