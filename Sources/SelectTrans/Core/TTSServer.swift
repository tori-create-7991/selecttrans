import Foundation
import Network

/// Loopback-only HTTP server exposing `POST /speak`, so local tools (e.g. a
/// Claude Code Stop hook) can trigger TTS without shipping their own speech
/// synthesis. Bound to 127.0.0.1 only — never reachable from the network.
@MainActor
final class TTSServer {
    static let shared = TTSServer()

    struct SpeakRequestBody: Decodable {
        let text: String
        let lang: String?
        let repo: String?
        let session: String?
    }

    /// Above this, a request is almost certainly not a TTS payload — refuse it
    /// rather than let a runaway sender grow the receive buffer unbounded.
    private static let maxRequestBytes = 1_000_000
    private static let maxConcurrentConnections = 16

    private var listener: NWListener?
    private let port: NWEndpoint.Port
    private var activeConnections: Set<ObjectIdentifier> = []

    /// Set once the listener reaches `.ready`; `nil` while stopped or failed
    /// (e.g. the requested port is already in use by another process).
    private(set) var boundPort: UInt16?

    init(port: UInt16 = 8765) {
        self.port = NWEndpoint.Port(rawValue: port) ?? 8765
    }

    func start() {
        guard listener == nil else { return }

        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: .ipv4(.loopback),
            port: port
        )

        do {
            let listener = try NWListener(using: params)
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in
                    self?.accept(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleStateChange(state)
                }
            }
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            NSLog("[SelectTrans] TTSServer failed to start: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        boundPort = nil
        activeConnections.removeAll()
    }

    private func handleStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            boundPort = listener?.port?.rawValue
        case .failed(let error):
            NSLog("[SelectTrans] TTSServer listener failed (port \(port) likely in use): \(error)")
            listener = nil
            boundPort = nil
        case .cancelled:
            listener = nil
            boundPort = nil
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        guard activeConnections.count < Self.maxConcurrentConnections else {
            connection.cancel()
            return
        }
        activeConnections.insert(ObjectIdentifier(connection))
        connection.start(queue: .main)
        receive(on: connection, buffer: Data())
    }

    private func finish(_ connection: NWConnection) {
        activeConnections.remove(ObjectIdentifier(connection))
        connection.cancel()
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }

                var buffer = buffer
                if let data, !data.isEmpty {
                    buffer.append(data)
                }

                if buffer.count > Self.maxRequestBytes {
                    self.respond(status: "413 Payload Too Large", body: "", on: connection)
                    return
                }

                switch HTTPRequestParser.parse(buffer) {
                case .complete(let request):
                    self.handle(request, on: connection)
                case .invalid:
                    self.respond(status: "400 Bad Request", body: "", on: connection)
                case .incomplete:
                    if isComplete || error != nil {
                        self.finish(connection)
                        return
                    }
                    self.receive(on: connection, buffer: buffer)
                }
            }
        }
    }

    private func handle(_ request: HTTPRequestParser.Request, on connection: NWConnection) {
        if request.method == "GET", request.path == "/health" {
            respond(status: "200 OK", body: "", on: connection)
            return
        }

        guard request.method == "POST", request.path == "/speak" else {
            respond(status: "404 Not Found", body: "", on: connection)
            return
        }

        guard let body = try? JSONDecoder().decode(SpeakRequestBody.self, from: request.body),
              !body.text.isEmpty
        else {
            respond(status: "400 Bad Request", body: "", on: connection)
            return
        }

        let preferences = TTSPreferenceStore()
        let repo = body.repo ?? ""
        let includeRepoPrefix = preferences.speakRepoPrefix && !repo.isEmpty
        let fullText = includeRepoPrefix ? "\(repo). \(body.text)" : body.text
        let language = resolveLanguage(explicit: body.lang, text: fullText, preferences: preferences)

        Speaker.shared.speak(fullText, language: language, repo: repo, displayText: body.text)
        TTSHistoryStore.shared.record(repo: repo, session: body.session ?? "", text: body.text)

        respond(status: "200 OK", body: "", on: connection)
    }

    private func resolveLanguage(explicit: String?, text: String, preferences: TTSPreferenceStore) -> String {
        switch preferences.languageMode {
        case .forcedJapanese: return "ja-JP"
        case .forcedEnglish: return "en-US"
        case .auto: break
        }
        guard let explicit, explicit != "auto", !explicit.isEmpty else {
            return LangDetector.speechLanguage(for: text, threshold: preferences.cjkThreshold)
        }
        return explicit
    }

    private func respond(status: String, body: String, on connection: NWConnection) {
        let response = "HTTP/1.1 \(status)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] _ in
            Task { @MainActor in
                self?.finish(connection)
            }
        })
    }
}
