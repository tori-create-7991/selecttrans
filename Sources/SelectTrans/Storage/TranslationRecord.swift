import Foundation

struct TranslationRecord: Codable, Sendable {
    let source: String
    let result: String
    let direction: String
    let mode: String
    let app: String
    let date: String
    let engine: String

    init(source: String, result: String, direction: String, mode: String, app: String, date: String, engine: String = "Gemini") {
        self.source = source
        self.result = result
        self.direction = direction
        self.mode = mode
        self.app = app
        self.date = date
        self.engine = engine
    }
}
