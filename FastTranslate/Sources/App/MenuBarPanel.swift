import AppKit

/// Borderless floating panel used as a drop-in replacement for `NSPopover`
/// in the menu bar. Unlike `NSPopover`, it gives full control over the
/// window chrome, which is required to apply the SwiftUI `.glassEffect()`
/// (Liquid Glass) background to the hosted content.
///
/// Positioning mimics `NSPopover.show(relativeTo:of:preferredEdge: .minY)`:
/// the panel is anchored centered horizontally under the status item button,
/// clamped to the visible frame of the screen that owns the status button.
///
/// Note: dropping `NSPopover` loses the triangular arrow. This is an
/// accepted trade-off for the Liquid Glass appearance.
@MainActor
final class MenuBarPanel {

    // MARK: - Stored properties

    private let panel: NSPanel
    private var resignKeyObserver: NSObjectProtocol?

    // Gap between the status bar button and the top of the panel.
    private let verticalGap: CGFloat = 4

    // MARK: - Init

    init(contentViewController: NSViewController) {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.worksWhenModal = false

        panel.contentViewController = contentViewController

        // Auto-close when the user clicks elsewhere and the panel loses key status.
        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // Hop back to the main actor to call close().
            Task { @MainActor in
                self?.close()
            }
        }
    }

    deinit {
        if let resignKeyObserver {
            NotificationCenter.default.removeObserver(resignKeyObserver)
        }
    }

    // MARK: - Public API

    /// Mirrors `NSPopover.isShown`.
    var isShown: Bool { panel.isVisible }

    /// Positions the panel directly below the given status bar button and
    /// makes it the key window.
    func show(relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }

        // Make sure we know the panel's desired size (driven by SwiftUI intrinsic
        // content size on the hosted view). `layoutIfNeeded` forces Auto Layout
        // to resolve the fitting size before we read `frame`.
        panel.contentView?.layoutSubtreeIfNeeded()
        let panelSize = panel.frame.size

        // Convert the button's bounds to screen coordinates.
        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)

        var origin = NSPoint(
            x: buttonFrameOnScreen.midX - panelSize.width / 2,
            y: buttonFrameOnScreen.minY - panelSize.height - verticalGap
        )

        // Clamp to the visible frame of the screen that hosts the status button.
        let screen = buttonWindow.screen ?? NSScreen.main
        if let visibleFrame = screen?.visibleFrame {
            let maxX = visibleFrame.maxX - panelSize.width
            let minX = visibleFrame.minX
            origin.x = min(max(origin.x, minX), maxX)

            let minY = visibleFrame.minY
            origin.y = max(origin.y, minY)
        }

        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Mirrors `NSPopover.performClose(_:)` semantics for our use.
    func close() {
        panel.orderOut(nil)
    }
}
