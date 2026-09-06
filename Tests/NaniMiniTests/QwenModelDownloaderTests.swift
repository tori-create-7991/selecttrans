import Testing
@testable import NaniMini

struct QwenModelDownloaderTests {
    @Test func acceptsTheHuggingFaceLFSHashPrefix() {
        let hash = String(repeating: "a", count: 64)
        #expect(QwenModelDownloader.sha256Digest(fromLFSOID: "sha256:\(hash)") == hash)
    }

    @Test func rejectsMalformedLFSHashes() {
        #expect(QwenModelDownloader.sha256Digest(fromLFSOID: "sha256:abc") == nil)
        #expect(QwenModelDownloader.sha256Digest(fromLFSOID: "sha1:" + String(repeating: "a", count: 64)) == nil)
    }
}
