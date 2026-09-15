import AppKit

/// Interactive region capture using the native `screencapture -i` crosshair UI.
/// Requires Screen Recording permission (prompted on first use).
enum ScreenCapture {
    static func captureInteractive() async -> CGImage? {
        let path = NSTemporaryDirectory() + "selecttrans_\(UUID().uuidString).png"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", path]  // -i interactive, -x no sound

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
            do {
                try process.run()
            } catch {
                continuation.resume()
            }
        }

        defer { try? FileManager.default.removeItem(atPath: path) }
        guard
            let image = NSImage(contentsOfFile: path),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }   // user cancelled (Esc) -> no file
        return cgImage
    }
}
