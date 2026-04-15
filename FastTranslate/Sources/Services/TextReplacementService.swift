import Cocoa

struct SavedClipboardItem {
    let entries: [(NSPasteboard.PasteboardType, Data)]
}

@MainActor
protocol TextReplacing {
    func replaceSelection(with text: String) async
}

@MainActor
final class TextReplacementService: TextReplacing {

    func replaceSelection(with text: String) async {
        guard !text.isEmpty else { return }
        let saved = saveClipboard()
        await paste(text)
        restoreClipboard(saved)
    }

    func saveClipboard() -> [SavedClipboardItem] {
        let pasteboard = NSPasteboard.general
        return pasteboard.pasteboardItems?.map { item in
            let entries = item.types.compactMap { type -> (NSPasteboard.PasteboardType, Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
            return SavedClipboardItem(entries: entries)
        } ?? []
    }

    func restoreClipboard(_ items: [SavedClipboardItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        for saved in items {
            let item = NSPasteboardItem()
            for (type, data) in saved.entries {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }
    }

    func paste(_ text: String) async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        try? await Task.sleep(for: .milliseconds(100))

        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        try? await Task.sleep(for: .milliseconds(150))
    }
}
