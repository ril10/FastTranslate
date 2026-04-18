import Cocoa
import ApplicationServices

@MainActor
protocol AccessibilityPermissionChecking {
    var isTrusted: Bool { get }
    func promptIfNeeded()
}

@MainActor
final class AccessibilityPermissionService: AccessibilityPermissionChecking {

    var isTrusted: Bool { AXIsProcessTrusted() }

    func promptIfNeeded() {
        guard !isTrusted else { return }
        let alert = NSAlert()
        alert.messageText = "Accessibility permission required"
        alert.informativeText = "FastTranslate needs Accessibility permission to replace selected text. Open System Settings to grant it."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
