import Foundation
import Testing
@testable import SelectTrans

struct QwenMLXTranslationEngineTests {
    @Test func acceptsSplitSafetensorsWeightsForCustomModel() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("QwenMLXTranslationEngineTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for file in ["config.json", "tokenizer.json", "model-00001-of-00002.safetensors"] {
            FileManager.default.createFile(atPath: directory.appendingPathComponent(file).path, contents: Data())
        }

        let availability = await QwenMLXTranslationEngine(modelDirectory: directory).availability()

        #expect(availability.isAvailable)
    }

    /// Opt-in hardware integration test. It is deliberately disabled in CI:
    /// the real model is about 869 MB and is supplied only by the local user.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SELECTTRANS_QWEN_INTEGRATION"] == "1"))
    func loadsTheDownloadedModelAndGeneratesText() async throws {
        let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SELECTTRANS_QWEN_MODEL_PATH"] ?? "")
        let engine = QwenMLXTranslationEngine(modelDirectory: directory)
        let availability = await engine.availability()
        #expect(availability.isAvailable)

        var output = ""
        try await engine.translate(
            prompt: "Reply with only: ready",
            mode: .translate
        ) { output += $0 }

        #expect(!output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
