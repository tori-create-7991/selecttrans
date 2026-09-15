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

    private let synthesizer = AVSpeechSynthesizer()
    private var queue: [AVSpeechUtterance] = []
    private var isSpeaking = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, language: String) {
        guard !text.isEmpty, queue.count < Self.maxQueueSize else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        queue.append(utterance)
        speakNextIfIdle()
    }

    private func speakNextIfIdle() {
        guard !isSpeaking, !queue.isEmpty else { return }
        isSpeaking = true
        let next = queue.removeFirst()
        synthesizer.speak(next)
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
