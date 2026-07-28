import Testing
@testable import NaniMini

@Suite("GeminiClient requests")
struct GeminiClientRequestTests {
    @Test("API key is sent in a header, not the URL")
    func apiKeyUsesHeader() {
        let request = GeminiClient.makeRequest(
            key: "secret-key",
            prompt: "hello",
            model: "gemini-test",
            streaming: true
        )

        #expect(request.value(forHTTPHeaderField: "x-goog-api-key") == "secret-key")
        #expect(request.url?.query?.contains("key=") == false)
        #expect(request.url?.query?.contains("alt=sse") == true)
    }
}
