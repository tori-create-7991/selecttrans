import AppKit
import Carbon.HIToolbox

/// Grabs the currently-selected text in ANY app by sending a synthetic Cmd+C
/// and reading the clipboard. Requires Accessibility permission.
enum TextGrabber {
    static func grabSelectedText() -> String? {
        let pasteboard = NSPasteboard.general
        let previousCount = pasteboard.changeCount

        sendCommandC()

        // Wait briefly for the target app to update the pasteboard.
        let deadline = Date().addingTimeInterval(0.4)
        while pasteboard.changeCount == previousCount, Date() < deadline {
            usleep(15_000)
        }
        guard pasteboard.changeCount != previousCount else { return nil }
        return pasteboard.string(forType: .string)
    }

    private static func sendCommandC() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)
        cDown?.flags = .maskCommand
        cUp?.flags = .maskCommand
        let location = CGEventTapLocation.cghidEventTap
        cDown?.post(tap: location)
        cUp?.post(tap: location)
    }
}
