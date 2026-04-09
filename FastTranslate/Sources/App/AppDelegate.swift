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
        hotkeyService = nil
        menuBarController = nil
        floatingPanel = nil
    }

    // MARK: - Hotkey Handler

    private func handleHotkey() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let settings = AppSettings.shared
            guard settings.inlineTranslation else { return }

            let pasteboard = NSPasteboard.general

            // Save all clipboard types
            let savedItems: [[(NSPasteboard.PasteboardType, Data)]] = pasteboard.pasteboardItems?.map { item in
                item.types.compactMap { type in
                    guard let data = item.data(forType: type) else { return nil }
                    return (type, data)
                }
            } ?? []

            // Simulate Cmd+C to copy selected text
            let src = CGEventSource(stateID: .hidSystemState)
            let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
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
            for itemTypes in savedItems {
                let item = NSPasteboardItem()
                for (type, data) in itemTypes {
                    item.setData(data, forType: type)
                }
                pasteboard.writeObjects([item])
            }

            guard !text.isEmpty else { return }

            let mouseLocation = NSEvent.mouseLocation
            let provider = OllamaProvider(baseURL: settings.ollamaURL, model: settings.selectedModel)
            self.floatingPanel?.show(text: text, near: mouseLocation, provider: provider)
        }
    }
}
