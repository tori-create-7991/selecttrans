import Foundation

enum TranslationOutputParser {
    static func backTranslationInput(from output: String) -> String {
        if let natural = section(named: "自然な訳", in: output) {
            return natural
        }

        if let literal = section(named: "直訳", in: output) {
            return literal
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func section(named name: String, in output: String) -> String? {
        let marker = "【\(name)】"
        guard let markerRange = output.range(of: marker) else { return nil }

        let remainder = output[markerRange.upperBound...]
        let nextMarker = remainder.range(of: "\n【")
        let section = nextMarker.map { remainder[..<$0.lowerBound] } ?? Substring(remainder)
        let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmed.isEmpty ? nil : trimmed
    }
}
