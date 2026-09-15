import Foundation
import Testing
@testable import NaniMini

struct HTTPRequestParserTests {
    @Test func parsesCompleteRequestWithBody() {
        let raw = "POST /speak HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: 13\r\n\r\n{\"text\":\"hi\"}"
        let data = Data(raw.utf8)

        let request = HTTPRequestParser.parse(data)

        #expect(request?.method == "POST")
        #expect(request?.path == "/speak")
        #expect(request.map { String(data: $0.body, encoding: .utf8) } == "{\"text\":\"hi\"}")
    }

    @Test func returnsNilWhenHeadersIncomplete() {
        let raw = "POST /speak HTTP/1.1\r\nContent-Length: 13\r\n"
        #expect(HTTPRequestParser.parse(Data(raw.utf8)) == nil)
    }

    @Test func returnsNilWhenBodyIncomplete() {
        let raw = "POST /speak HTTP/1.1\r\nContent-Length: 13\r\n\r\n{\"text\":\"h"
        #expect(HTTPRequestParser.parse(Data(raw.utf8)) == nil)
    }

    @Test func parsesRequestWithNoBody() {
        let raw = "GET /health HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"
        let request = HTTPRequestParser.parse(Data(raw.utf8))

        #expect(request?.method == "GET")
        #expect(request?.path == "/health")
        #expect(request?.body.isEmpty == true)
    }
}
