import Foundation
import Testing
@testable import SelectTrans

struct HTTPRequestParserTests {
    @Test func parsesCompleteRequestWithBody() {
        let raw = "POST /speak HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: 13\r\n\r\n{\"text\":\"hi\"}"
        let data = Data(raw.utf8)

        guard case .complete(let request) = HTTPRequestParser.parse(data) else {
            Issue.record("expected a complete request")
            return
        }

        #expect(request.method == "POST")
        #expect(request.path == "/speak")
        #expect(String(data: request.body, encoding: .utf8) == "{\"text\":\"hi\"}")
    }

    @Test func returnsIncompleteWhenHeadersIncomplete() {
        let raw = "POST /speak HTTP/1.1\r\nContent-Length: 13\r\n"
        #expect(HTTPRequestParser.parse(Data(raw.utf8)) == .incomplete)
    }

    @Test func returnsIncompleteWhenBodyIncomplete() {
        let raw = "POST /speak HTTP/1.1\r\nContent-Length: 13\r\n\r\n{\"text\":\"h"
        #expect(HTTPRequestParser.parse(Data(raw.utf8)) == .incomplete)
    }

    @Test func parsesRequestWithNoBody() {
        let raw = "GET /health HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        guard case .complete(let request) = HTTPRequestParser.parse(Data(raw.utf8)) else {
            Issue.record("expected a complete request")
            return
        }

        #expect(request.method == "GET")
        #expect(request.path == "/health")
        #expect(request.body.isEmpty)
    }

    @Test func returnsInvalidForNegativeContentLength() {
        let raw = "POST /speak HTTP/1.1\r\nContent-Length: -1\r\n\r\n"
        #expect(HTTPRequestParser.parse(Data(raw.utf8)) == .invalid)
    }

    @Test func returnsInvalidForNonNumericContentLength() {
        let raw = "POST /speak HTTP/1.1\r\nContent-Length: abc\r\n\r\n"
        #expect(HTTPRequestParser.parse(Data(raw.utf8)) == .invalid)
    }

    @Test func treatsMissingContentLengthAsZero() {
        let raw = "POST /speak HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        guard case .complete(let request) = HTTPRequestParser.parse(Data(raw.utf8)) else {
            Issue.record("expected a complete request")
            return
        }
        #expect(request.body.isEmpty)
    }
}
