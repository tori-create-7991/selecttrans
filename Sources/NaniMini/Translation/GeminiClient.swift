import Foundation

/// Gemini client. Streaming (SSE) for the live UI, plus a non-streaming call for
/// back-translation and a tiny warm-up to keep the connection/model hot.
/// The API key lives in the Keychain, not in source.
struct GeminiClient {
    enum GeminiError: LocalizedError {
        case missingKey
        case rateLimited
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .missingKey:
                return "Gemini APIキーが未設定です。メニューバー → 設定 から入力してください。"
            case .rateLimited:
                return "Gemini 無料枠のレート制限に達しました（429）。\n1分ほど待つか、課金の有効化／モデル変更をご検討ください。"
            case .badResponse(let detail):
                return "翻訳に失敗しました: \(detail)"
            }
        }
    }

    // 429 (quota) is intentionally NOT retried — retrying just burns more quota.
    private static let retryableStatus: Set<Int> = [500, 502, 503]
    private static let maxAttempts = 3

    // MARK: - Streaming

    /// Streams the translation. `onDelta` is called on the main actor for each text chunk.
    func translateStream(prompt: String, model: String, onDelta: @escaping @MainActor (String) -> Void) async throws {
        guard let key = KeychainStore.get(.geminiAPIKey), !key.isEmpty else {
            throw GeminiError.missingKey
        }
        let request = Self.makeRequest(key: key, prompt: prompt, model: model, streaming: true)

        var lastDetail = "unknown"
        for attempt in 0..<Self.maxAttempts {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GeminiError.badResponse("no HTTP response")
            }

            if http.statusCode == 200 {
                for try await line in bytes.lines {
                    guard line.hasPrefix("data:") else { continue }
                    let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                    guard !payload.isEmpty, payload != "[DONE]" else { continue }
                    if let delta = Self.parseDelta(payload), !delta.isEmpty {
                        await onDelta(delta)
                    }
                }
                return
            }

            if http.statusCode == 429 { throw GeminiError.rateLimited }

            // Drain the body to surface the error detail.
            var errorData = Data()
            for try await byte in bytes { errorData.append(byte) }
            lastDetail = String(data: errorData, encoding: .utf8) ?? "unknown"

            guard Self.retryableStatus.contains(http.statusCode), attempt < Self.maxAttempts - 1 else {
                throw GeminiError.badResponse(lastDetail)
            }
            try await Task.sleep(nanoseconds: Self.backoff(attempt))
        }
        throw GeminiError.badResponse(lastDetail)
    }

    // MARK: - Non-streaming (back-translation)

    func translate(prompt: String, model: String) async throws -> String {
        guard let key = KeychainStore.get(.geminiAPIKey), !key.isEmpty else {
            throw GeminiError.missingKey
        }
        let request = Self.makeRequest(key: key, prompt: prompt, model: model, streaming: false)

        var lastDetail = "unknown"
        for attempt in 0..<Self.maxAttempts {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GeminiError.badResponse("no HTTP response")
            }
            if http.statusCode == 200 {
                return try Self.parse(data)
            }
            if http.statusCode == 429 { throw GeminiError.rateLimited }
            lastDetail = String(data: data, encoding: .utf8) ?? "unknown"
            guard Self.retryableStatus.contains(http.statusCode), attempt < Self.maxAttempts - 1 else {
                throw GeminiError.badResponse(lastDetail)
            }
            try await Task.sleep(nanoseconds: Self.backoff(attempt))
        }
        throw GeminiError.badResponse(lastDetail)
    }

    // MARK: - Warm-up

    /// Warms the TLS/HTTP connection WITHOUT spending generate_content quota by
    /// hitting the (cheap) model-list endpoint instead of generateContent.
    func warmUp() async {
        guard let key = KeychainStore.get(.geminiAPIKey), !key.isEmpty else { return }
        var components = URLComponents(string: Config.geminiEndpoint)!  // ".../models"
        components.queryItems = [
            URLQueryItem(name: "pageSize", value: "1")
        ]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Helpers

    static func makeRequest(key: String, prompt: String, model: String, streaming: Bool) -> URLRequest {
        let method = streaming ? "streamGenerateContent" : "generateContent"
        var components = URLComponents(string: "\(Config.geminiEndpoint)/\(model):\(method)")!
        components.queryItems = streaming
            ? [URLQueryItem(name: "alt", value: "sse")]
            : nil

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.3]
        ])
        return request
    }

    private static func backoff(_ attempt: Int) -> UInt64 {
        UInt64(0.6 * pow(2.0, Double(attempt)) * 1_000_000_000)
    }

    private static func parseDelta(_ jsonString: String) -> String? {
        guard
            let data = jsonString.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else { return nil }
        return parts.compactMap { $0["text"] as? String }.joined()
    }

    private static func parse(_ data: Data) throws -> String {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content = candidates.first?["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]],
            let text = parts.first?["text"] as? String
        else {
            throw GeminiError.badResponse(String(data: data, encoding: .utf8) ?? "parse error")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
