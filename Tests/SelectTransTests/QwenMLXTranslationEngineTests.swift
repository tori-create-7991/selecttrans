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
}
