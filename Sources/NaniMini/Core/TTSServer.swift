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

    private var listener: NWListener?
    private let port: NWEndpoint.Port

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
            listener.start(queue: .main)
            self.listener = listener
        } catch {
            NSLog("[SelectTrans] TTSServer failed to start: \(error)")
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: .main)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                guard let self else { return }

                var buffer = buffer
                if let data, !data.isEmpty {
                    buffer.append(data)
                }

                if let request = HTTPRequestParser.parse(buffer) {
                    self.handle(request, on: connection)
                    return
                }

                if isComplete || error != nil {
                    connection.cancel()
                    return
                }

                self.receive(on: connection, buffer: buffer)
            }
        }
    }

    private func handle(_ request: HTTPRequestParser.Request, on connection: NWConnection) {
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

        let repo = body.repo ?? ""
        let fullText = repo.isEmpty ? body.text : "\(repo). \(body.text)"
        let language = resolveLanguage(explicit: body.lang, text: fullText)

        Speaker.shared.speak(fullText, language: language)
        TTSHistoryStore.shared.record(repo: repo, session: body.session ?? "", text: body.text)

        respond(status: "200 OK", body: "", on: connection)
    }

    private func resolveLanguage(explicit: String?, text: String) -> String {
        guard let explicit, explicit != "auto", !explicit.isEmpty else {
            return LangDetector.speechLanguage(for: text)
        }
        return explicit
    }

    private func respond(status: String, body: String, on connection: NWConnection) {
        let response = "HTTP/1.1 \(status)\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
