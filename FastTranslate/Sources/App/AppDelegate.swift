import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var menuBarController: MenuBarController?
    private var hotkeyService: GlobalHotkeyService?
    private var floatingPanel: FloatingTranslationPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()
        floatingPanel = FloatingTranslationPanel()

        hotkeyService = GlobalHotkeyService { [weak self] in
            self?.handleHotkey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarController = nil
        hotkeyService = nil
        floatingPanel = nil
    }

    // MARK: - Hotkey Handler

    private func handleHotkey() {
        let settings = AppSettings.shared
        guard settings.inlineTranslation else { return }

        Task { @MainActor in
            // Save current clipboard
            let pasteboard = NSPasteboard.general
            let savedContents = pasteboard.pasteboardItems?.compactMap { item -> (NSPasteboard.PasteboardType, Data)? in
                guard let types = item.types.first, let data = item.data(forType: types) else { return nil }
                return (types, data)
            }

            // Simulate Cmd+C to copy selected text
            let src = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true) // 'c'
            let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
            keyDown?.flags = .maskCommand
            keyUp?.flags = .maskCommand
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)

            // Wait for clipboard to update
            try? await Task.sleep(for: .milliseconds(150))

            let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // Restore clipboard
            pasteboard.clearContents()
            if let saved = savedContents {
                for (type, data) in saved {
                    pasteboard.setData(data, forType: type)
                }
            }

            guard !text.isEmpty else { return }

            let mouseLocation = NSEvent.mouseLocation
            let provider = OllamaProvider(baseURL: settings.ollamaURL, model: settings.selectedModel)
            self.floatingPanel?.show(text: text, near: mouseLocation, provider: provider)
        }
    }
}
