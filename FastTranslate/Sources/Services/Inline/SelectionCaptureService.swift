import Cocoa

@MainActor
protocol SelectionCapturing {
    func captureSelectedText() async -> String
}

@MainActor
final class SelectionCaptureService: SelectionCapturing {

    func captureSelectedText() async -> String {
        let snapshot = ClipboardSnapshot()

        let src = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)

        try? await Task.sleep(for: .milliseconds(150))

        let text = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        snapshot.restore()
        return text
    }
}
