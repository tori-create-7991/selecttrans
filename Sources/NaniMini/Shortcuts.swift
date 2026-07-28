import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// Translate the current text selection. Default: Control + J.
    static let translate = Self("translate", default: .init(.j, modifiers: [.control]))

    /// Screenshot a region, OCR it, then translate. Default: Control + Shift + J.
    static let translateCapture = Self("translateCapture", default: .init(.j, modifiers: [.control, .shift]))
}
