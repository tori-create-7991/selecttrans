import Foundation

/// Minimal HTTP/1.1 request parser for the loopback-only TTS server.
/// Handles exactly what `POST /speak` needs: request line, Content-Length,
/// and a body — nothing else (no chunked encoding, no headers exposed).
enum HTTPRequestParser {
    struct Request: Equatable {
        let method: String
        let path: String
        let body: Data
    }

    /// Parses `buffer` if a complete request (headers + full body) is present.
    /// Returns `nil` when more bytes are needed.
    static func parse(_ buffer: Data) -> Request? {
        let headerTerminator = Data("\r\n\r\n".utf8)
        guard let headerEndRange = buffer.range(of: headerTerminator) else { return nil }

        let headerData = buffer[..<headerEndRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let method = String(parts[0])
        let path = String(parts[1])

        var contentLength = 0
        for line in lines.dropFirst() {
            let headerParts = line.split(separator: ":", maxSplits: 1)
            guard headerParts.count == 2 else { continue }
            if headerParts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                contentLength = Int(headerParts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        let bodyStart = headerEndRange.upperBound
        let availableBody = buffer[bodyStart...]
        guard availableBody.count >= contentLength else { return nil }

        let body = availableBody.prefix(contentLength)
        return Request(method: method, path: path, body: Data(body))
    }
}
