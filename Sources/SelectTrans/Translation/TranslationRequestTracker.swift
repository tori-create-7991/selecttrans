struct TranslationRequestTracker {
    private var generation = 0

    mutating func begin() -> Int {
        generation += 1
        return generation
    }

    func isCurrent(_ request: Int) -> Bool {
        request == generation
    }
}
