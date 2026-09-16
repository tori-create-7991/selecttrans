import AVFoundation

/// Text-to-speech via the system synthesizer. Free, on-device, no API.
///
/// Requests are queued FIFO instead of interrupting the current utterance,
/// because the local TTS HTTP server can receive several requests back to
/// back and callers expect every one of them to be heard in order.
@MainActor
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker()

    /// Caps how many utterances can be waiting at once, so a runaway or
    /// malicious caller can't queue the app into reading forever.
    private static let maxQueueSize = 50

    private struct QueueItem {
        let utterance: AVSpeechUtterance
        let display: TTSSpeakingItem
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var queue: [QueueItem] = []
    private var isSpeaking = false
    private let preferences = TTSPreferenceStore()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// - Parameters:
    ///   - text: full text to speak (may include a repo prefix already mixed in).
    ///   - language: BCP-47 code (`en-US`/`ja-JP`) used to pick the voice.
    ///   - repo/displayText: kept separately only for the "now speaking" popup.
    func speak(_ text: String, language: String, repo: String = "", displayText: String? = nil) {
        guard !preferences.isMuted else { return }

        let truncated = truncate(text)
        guard !truncated.isEmpty, queue.count < Self.maxQueueSize else { return }

        let utterance = AVSpeechUtterance(string: truncated)
        utterance.voice = preferences.character.voice(language: language)
        utterance.rate = preferences.rate
        utterance.volume = preferences.volume
        utterance.pitchMultiplier = preferences.pitch

        let display = TTSSpeakingItem(repo: repo, text: displayText ?? text)
        queue.append(QueueItem(utterance: utterance, display: display))
        speakNextIfIdle()
    }

    /// Stops the current utterance and drops everything still queued.
    func stopAll() {
        queue.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
    }

    private func truncate(_ text: String) -> String {
        let limit = preferences.maxCharacters
        guard limit > 0, text.count > limit else { return text }
        return String(text.prefix(limit))
    }

    private func speakNextIfIdle() {
        guard !isSpeaking, !queue.isEmpty else {
            if queue.isEmpty { TTSSpeakingNowStore.shared.set(nil) }
            return
        }
        isSpeaking = true
        let next = queue.removeFirst()
        TTSSpeakingNowStore.shared.set(next.display)
        synthesizer.speak(next.utterance)
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            isSpeaking = false
            speakNextIfIdle()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            isSpeaking = false
            speakNextIfIdle()
        }
    }
}
