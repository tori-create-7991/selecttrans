import AppKit
import SwiftUI
import KeyboardShortcuts
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var ttsServerToggleItem: NSMenuItem?
    private var translationSettingsWindow: NSWindow?
    private var speechSettingsWindow: NSWindow?
    private var ttsHistoryWindow: NSWindow?
    private var warmUpTimer: Timer?

    private let popup = PopupPanel()
    private let speakingPopup = TTSSpeakingPopupPanel()
    private let translator = Translator()
    private let translationPreferences = TranslationPreferenceStore()

    private var currentMode: TranslationMode = .translate
    private var lastText = ""
    private var lastSourceApp = ""
    private var translationTask: Task<Void, Never>?
    private var translationRequests = TranslationRequestTracker()

    /// Caches output per mode for the current source text, so toggling the
    /// 翻訳/添削 tabs doesn't re-hit the API (which was burning the free quota).
    private var resultCache = TranslationResultCache()

    func applicationDidFinishLaunching(_ notification: Notification) {
        LegacyHistoryCleanup.removePendingQueue()
        setupMainMenu()
        setupStatusItem()

        KeyboardShortcuts.onKeyUp(for: .translate) { [weak self] in
            self?.handleHotkey()
        }
        KeyboardShortcuts.onKeyUp(for: .translateCapture) { [weak self] in
            self?.handleCaptureHotkey()
        }
        popup.onModeChange = { [weak self] mode in
            guard let self else { return }
            self.currentMode = mode
            self.popup.model.mode = mode

            let fastLiteralDisplay = mode == .translate
                && self.translationPreferences.isFastLiteralDisplayEnabled
            if let cached = self.resultCache.value(
                for: mode,
                fastLiteralDisplay: fastLiteralDisplay,
                engine: TranslationEngineStore().selected
            ), !cached.isEmpty {
                self.cancelCurrentTranslation()
                // Already computed for this text — show it, no API call.
                self.popup.model.output = cached
                self.popup.model.isLoading = false
                self.popup.model.errorMessage = nil
                self.popup.model.backTranslation = nil
            } else {
                self.retranslate()
            }
        }
        popup.onTranslate = { [weak self] in
            self?.translateFromEditor()
        }
        popup.onBackTranslate = { [weak self] in
            self?.runBackTranslation()
        }

        // Performance: pre-build the panel and warm the connection/model.
        popup.prewarm()
        Task { await translator.warmUp() }
        warmUpTimer = Timer.scheduledTimer(withTimeInterval: 240, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.translator.warmUp() }
        }

        if TTSPreferenceStore().isServerEnabled {
            TTSServer.shared.start()
        }
        speakingPopup.start()
    }

    // MARK: - Main menu (enables ⌘W to close + ⌘C/⌘V/⌘X/⌘A in editors)

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "SelectTrans を終了",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // Edit menu — standard text actions routed through the responder chain.
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "編集")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "取り消す", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "やり直す", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "カット", action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: "コピー", action: Selector(("copy:")), keyEquivalent: "c")
        editMenu.addItem(withTitle: "ペースト", action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(withTitle: "すべてを選択", action: Selector(("selectAll:")), keyEquivalent: "a")

        // Window menu — Close (⌘W) targets the key window via the responder chain.
        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "ウインドウ")
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "閉じる",
                           action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let image = NSImage(systemSymbolName: "text.bubble", accessibilityDescription: "SelectTrans")
        image?.isTemplate = true
        item.button?.image = image

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "翻訳履歴…", action: #selector(openTranslationHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "読み上げ履歴…", action: #selector(openTTSHistory), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "翻訳の設定…", action: #selector(openTranslationSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "読み上げの設定…", action: #selector(openSpeechSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        let ttsToggleItem = NSMenuItem(title: "読み上げサーバーを停止", action: #selector(toggleTTSServer), keyEquivalent: "")
        menu.addItem(ttsToggleItem)
        self.ttsServerToggleItem = ttsToggleItem
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    // MARK: - Selection translation (Ctrl+J)

    private func handleHotkey() {
        NSLog("[SelectTrans] hotkey fired; AXIsProcessTrusted=\(AXIsProcessTrusted())")

        // Accessibility is required to send the synthetic Cmd+C that grabs selection.
        guard AXIsProcessTrusted() else {
            promptForAccessibility()
            showMessage("アクセシビリティ権限がありません。\n\nSystem Settings → プライバシーとセキュリティ → アクセシビリティ で SelectTrans を ON にしてください。")
            return
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        let grabbed = TextGrabber.grabSelectedText()
        NSLog("[SelectTrans] grabbed text length=\(grabbed?.count ?? -1)")

        guard
            let text = grabbed,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            // Nothing selected -> open a blank editor for manual input.
            openEmptyEditor(sourceApp: sourceApp)
            return
        }

        startTranslation(text: text, sourceApp: sourceApp)
    }

    /// Opens the popup with an empty, editable source box (manual typing).
    private func openEmptyEditor(sourceApp: String) {
        cancelCurrentTranslation()
        lastText = ""
        lastSourceApp = sourceApp
        currentMode = .translate
        popup.model.source = ""
        popup.model.direction = ""
        popup.model.output = ""
        popup.model.backTranslation = nil
        popup.model.errorMessage = nil
        popup.model.isLoading = false
        popup.model.mode = .translate
        popup.show()
    }

    /// Translates whatever is currently in the (possibly edited) source editor.
    private func translateFromEditor() {
        let text = popup.model.source
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        lastText = text
        currentMode = popup.model.mode
        resultCache.removeAll()   // edited source -> stale cache

        let direction = LangDetector.direction(for: text)
        popup.model.direction = direction.label
        popup.model.outputLanguage = (direction == .enToJa) ? "ja-JP" : "en-US"
        popup.model.output = ""
        popup.model.backTranslation = nil
        popup.model.errorMessage = nil
        popup.model.isLoading = true

        translate()
    }

    // MARK: - Screenshot translation (Ctrl+Shift+J / menu)

    private func handleCaptureHotkey() {
        Task {
            guard let image = await ScreenCapture.captureInteractive() else { return } // cancelled
            let text = await OCRService.recognizeText(in: image)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                showMessage("画像から文字を認識できませんでした。")
                return
            }
            startTranslation(text: text, sourceApp: "スクショ")
        }
    }

    // MARK: - Shared flow

    private func startTranslation(text: String, sourceApp: String) {
        lastText = text
        lastSourceApp = sourceApp
        currentMode = .translate
        resultCache.removeAll()   // new source -> stale cache

        let direction = LangDetector.direction(for: text)
        popup.model.source = text
        popup.model.direction = direction.label
        popup.model.outputLanguage = (direction == .enToJa) ? "ja-JP" : "en-US"
        popup.model.mode = .translate
        popup.model.output = ""
        popup.model.backTranslation = nil
        popup.model.errorMessage = nil
        popup.model.isLoading = true
        popup.show()

        translate()
    }

    private func retranslate() {
        guard !lastText.isEmpty else { return }
        popup.model.output = ""
        popup.model.backTranslation = nil
        popup.model.errorMessage = nil
        popup.model.isLoading = true
        translate()
    }

    private func translate() {
        translationTask?.cancel()
        let request = translationRequests.begin()
        let text = lastText
        let mode = currentMode
        let sourceApp = lastSourceApp
        let preferences = translationPreferences.current
        let fastLiteralDisplay = mode == .translate
            && preferences.isFastLiteralDisplayEnabled
        translationTask = Task { [weak self] in
            guard let self else { return }
            do {
                var firstChunk = true
                let result = try await translator.runStream(
                    text: text,
                    mode: mode,
                    sourceApp: sourceApp,
                    preferences: preferences
                ) { [weak self] delta in
                    guard let self else { return }
                    guard self.translationRequests.isCurrent(request), !Task.isCancelled else { return }
                    if firstChunk {
                        self.popup.model.isLoading = false
                        firstChunk = false
                    }
                    self.popup.model.output += delta
                }
                guard translationRequests.isCurrent(request), !Task.isCancelled else { return }
                resultCache.set(
                    result.output,
                    for: mode,
                    fastLiteralDisplay: fastLiteralDisplay,
                    engine: TranslationEngineStore().selected
                )
            } catch is CancellationError {
                return
            } catch {
                guard translationRequests.isCurrent(request), !Task.isCancelled else { return }
                popup.model.errorMessage = error.localizedDescription
            }
            guard translationRequests.isCurrent(request), !Task.isCancelled else { return }
            popup.model.isLoading = false
        }
    }

    private func runBackTranslation() {
        let text = popup.model.output
        guard !text.isEmpty else { return }
        popup.model.isBackTranslating = true
        Task {
            do {
                popup.model.backTranslation = try await translator.backTranslate(text)
            } catch {
                popup.model.backTranslation = "(逆翻訳に失敗しました)"
            }
            popup.model.isBackTranslating = false
        }
    }

    // MARK: - Helpers

    private func promptForAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Shows the popup with a status/error message (no translation).
    private func showMessage(_ message: String) {
        cancelCurrentTranslation()
        lastText = ""
        popup.model.source = ""
        popup.model.direction = ""
        popup.model.output = ""
        popup.model.backTranslation = nil
        popup.model.isLoading = false
        popup.model.errorMessage = message
        popup.show()
    }

    private func cancelCurrentTranslation() {
        translationTask?.cancel()
        translationTask = nil
        _ = translationRequests.begin()
    }

    // MARK: - Actions

    @objc private func captureAction() {
        handleCaptureHotkey()
    }

    @objc private func openTranslationSettings() {
        if translationSettingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "SelectTrans 翻訳の設定"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            translationSettingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        translationSettingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openSpeechSettings() {
        if speechSettingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "SelectTrans 読み上げの設定"
            window.contentView = NSHostingView(rootView: SpeechSettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            speechSettingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        speechSettingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func openTranslationHistory() {
        let directory = MarkdownHistoryStore.defaultDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    @objc private func toggleTTSServer() {
        let preferences = TTSPreferenceStore()
        if TTSServer.shared.boundPort != nil {
            TTSServer.shared.stop()
            preferences.isServerEnabled = false
        } else {
            TTSServer.shared.start()
            preferences.isServerEnabled = true
        }
    }

    @objc private func openTTSHistory() {
        if ttsHistoryWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "読み上げ履歴"
            window.contentView = NSHostingView(rootView: TTSHistoryView())
            window.isReleasedWhenClosed = false
            window.center()
            ttsHistoryWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        ttsHistoryWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        ttsServerToggleItem?.title = TTSServer.shared.boundPort != nil
            ? "読み上げサーバーを停止"
            : "読み上げサーバーを開始"
    }
}
