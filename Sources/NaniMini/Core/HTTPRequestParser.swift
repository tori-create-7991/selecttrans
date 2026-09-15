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

    enum ParseResult: Equatable {
        /// Not enough bytes yet — caller should keep receiving.
        case incomplete
        /// The request is malformed (e.g. a negative or unparsable Content-Length)
        /// and must not be waited on further.
        case invalid
        case complete(Request)
    }

    /// Parses `buffer` if a complete request (headers + full body) is present.
    static func parse(_ buffer: Data) -> ParseResult {
        let headerTerminator = Data("\r\n\r\n".utf8)
        guard let headerEndRange = buffer.range(of: headerTerminator) else { return .incomplete }

        let headerData = buffer[..<headerEndRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return .invalid }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return .invalid }

        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return .invalid }
        let method = String(parts[0])
        let path = String(parts[1])

        var contentLength = 0
        for line in lines.dropFirst() {
            let headerParts = line.split(separator: ":", maxSplits: 1)
            guard headerParts.count == 2 else { continue }
            if headerParts[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length" {
                guard let value = Int(headerParts[1].trimmingCharacters(in: .whitespaces)), value >= 0 else {
                    return .invalid
                }
                contentLength = value
            }
        }

        let bodyStart = headerEndRange.upperBound
        let availableBody = buffer[bodyStart...]
        guard availableBody.count >= contentLength else { return .incomplete }

        let body = availableBody.prefix(contentLength)
        return .complete(Request(method: method, path: path, body: Data(body)))
    }
}
