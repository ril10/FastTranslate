import Cocoa

@MainActor
protocol TextReplacing {
    func replaceSelection(with text: String) async
}

@MainActor
final class TextReplacementService: TextReplacing {

    func replaceSelection(with text: String) async {
        guard !text.isEmpty else { return }
        let snapshot = ClipboardSnapshot()
        await paste(text)
        snapshot.restore()
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
