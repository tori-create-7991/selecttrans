import AppKit
import Combine
import SwiftUI

/// Floating panel that shows what `Speaker` is currently reading aloud.
/// Appears automatically when speech starts and hides itself when speech ends —
/// independent of the translation popup, which has its own show/hide lifecycle.
@MainActor
final class TTSSpeakingPopupPanel {
    private var panel: NSPanel?
    private var cancellable: AnyCancellable?
    private var escMonitor: Any?
    private var moveObserver: NSObjectProtocol?
    private let preferences = TTSPreferenceStore()

    func start() {
        guard cancellable == nil else { return }
        cancellable = TTSSpeakingNowStore.shared.$current
            .sink { [weak self] item in
                self?.update(item)
            }
    }

    private func update(_ item: TTSSpeakingItem?) {
        guard let item else {
            panel?.orderOut(nil)
            removeEscMonitor()
            return
        }
        let isFirstShow = panel == nil
        if panel == nil { build() }
        panel?.contentView = NSHostingView(rootView: TTSSpeakingPopupView(item: item))
        if isFirstShow { restorePositionOrDefault() }
        panel?.orderFront(nil)
        installEscMonitor()
    }

    private func build() {
        // KeyablePanel (defined in PopupPanel.swift) so clicking the popup lets
        // it take key focus and receive Esc — a plain panel would ignore clicks.
        let panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 320, height: 190)),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        // Lets the user drag the popup by its background to reposition it.
        panel.isMovableByWindowBackground = true
        self.panel = panel

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            self?.persistPosition()
        }
    }

    private func persistPosition() {
        guard let panel else { return }
        preferences.popupOrigin = panel.frame.origin
    }

    private func restorePositionOrDefault() {
        guard let panel else { return }
        guard let saved = preferences.popupOrigin, let screen = NSScreen.main else {
            positionBottomRight()
            return
        }
        // Clamp in case the saved position is now off-screen (resolution/display changed).
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let clamped = NSPoint(
            x: min(max(saved.x, visible.minX), visible.maxX - size.width),
            y: min(max(saved.y, visible.minY), visible.maxY - size.height)
        )
        panel.setFrameOrigin(clamped)
    }

    /// Esc closes the popup and stops speech, but only while the popup itself
    /// is the key window (i.e. the user clicked it first) — otherwise Esc in
    /// an unrelated window would silently cut off speech in the background.
    private func installEscMonitor() {
        guard escMonitor == nil else { return }
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, self.panel?.isKeyWindow == true else { return event }
            Speaker.shared.stopAll()
            return nil
        }
    }

    private func removeEscMonitor() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
    }

    private func positionBottomRight() {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(x: visible.maxX - size.width - 20, y: visible.minY + 20)
        panel.setFrameOrigin(origin)
    }
}
