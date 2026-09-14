import Testing
@testable import NaniMini

struct QwenModelDownloaderTests {
    @Test func acceptsTheHuggingFaceAPISHA256Value() {
        let hash = String(repeating: "a", count: 64)
        #expect(QwenModelDownloader.sha256Digest(hash) == hash)
        #expect(QwenModelDownloader.sha256Digest("sha256:\(hash)") == hash)
    }

    @Test func rejectsMalformedLFSHashes() {
        #expect(QwenModelDownloader.sha256Digest("sha256:abc") == nil)
        #expect(QwenModelDownloader.sha256Digest("sha1:" + String(repeating: "a", count: 64)) == nil)
    }
}
