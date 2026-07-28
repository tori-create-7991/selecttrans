import AppKit
import SwiftUI

/// NSPanel that can become the key window so it receives keyboard events
/// (Esc to close, Cmd+C to copy selected text). A plain titled panel in an
/// .accessory app would otherwise refuse key focus.
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// A floating panel that hosts the SwiftUI translation view and appears near the
/// cursor on the screen the mouse is currently on.
@MainActor
final class PopupPanel {
    static let size = NSSize(width: 440, height: 470)

    let model = PopupModel()
    var onModeChange: ((TranslationMode) -> Void)?
    var onTranslate: (() -> Void)?
    var onBackTranslate: (() -> Void)?

    private var panel: NSPanel?
    private var escMonitor: Any?

    /// Build the panel ahead of time so the first show has no construction lag.
    func prewarm() {
        if panel == nil { build() }
    }

    func show() {
        if panel == nil { build() }
        positionNearCursor()
        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        installEscMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        removeEscMonitor()
    }

    private func build() {
        let hosting = NSHostingView(rootView: PopupView(
            model: model,
            onModeChange: { [weak self] mode in self?.onModeChange?(mode) },
            onTranslate: { [weak self] in self?.onTranslate?() },
            onBackTranslate: { [weak self] in self?.onBackTranslate?() }
        ))
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting
        self.panel = panel
    }

    private func positionNearCursor() {
        guard let panel else { return }
        let size = Self.size
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - (size.height + 12))
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
        }
        panel.setFrameOrigin(origin)
    }

    private func installEscMonitor() {
        guard escMonitor == nil else { return }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.hide()
                return nil
            }
            return event
        }
    }

    private func removeEscMonitor() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
    }
}
