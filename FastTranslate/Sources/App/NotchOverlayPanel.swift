import Cocoa
import SwiftUI

/// Panel subclass that opts out of AppKit's automatic frame constraint.
/// `NSWindow.constrainFrameRect(_:to:)` clamps any proposed frame to the
/// destination screen's `visibleFrame` (below the menu bar). For an
/// overlay that must draw *over* the menu bar this constraint makes it
/// impossible to anchor the panel at `screen.frame.maxY` regardless of
/// window level.
final class NotchPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}

/// Borderless non-activating panel that sits above the menu bar and hosts
/// the rounded-rectangle pill rendered by `NotchOverlayView`. The panel's
/// top edge is anchored to the very top of the display; the SwiftUI layer
/// leaves the notch area transparent so the physical cutout shows through.
@MainActor
final class NotchOverlayPanel {

    private let panel: NotchPanel
    private let viewModel: NotchOverlayViewModel
    private let geometry: ScreenGeometryProviding
    private let hostingView: TopAlignedHostingView<NotchOverlayView>
    private var hideTask: Task<Void, Never>?

    /// Panel height; width matches the active screen so SwiftUI has enough
    /// horizontal room to center the pill under the notch on any display.
    static let panelHeight: CGFloat = 320

    /// Delay before tearing the window down after `hide()`, so the SwiftUI
    /// removal transition can finish. Matches the longest transition used
    /// in `NotchOverlayView`.
    private static let hideTransitionDelay: Duration = .milliseconds(550)

    init(
        viewModel: NotchOverlayViewModel,
        geometry: ScreenGeometryProviding,
        onCopy: @escaping () -> Void,
        onReplace: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.geometry = geometry

        guard let notchFrame = geometry.notchSafeFrame else {
            fatalError("NotchOverlayPanel must only be constructed when the active display has a notch")
        }
        let notchSize = CGSize(width: notchFrame.width, height: notchFrame.height)

        let initialScreenWidth = geometry.activeScreen?.frame.width
            ?? NSScreen.main?.frame.width
            ?? 1440

        let rootView = NotchOverlayView(
            viewModel: viewModel,
            notchSize: notchSize,
            onCopy: onCopy,
            onReplace: onReplace,
            onDismiss: onDismiss
        )
        self.hostingView = TopAlignedHostingView(rootView: rootView)
        self.hostingView.wantsLayer = true
        self.hostingView.layer?.backgroundColor = .clear
        self.hostingView.frame = NSRect(x: 0, y: 0, width: initialScreenWidth, height: Self.panelHeight)
        self.hostingView.autoresizingMask = [.width, .height]

        panel = NotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialScreenWidth, height: Self.panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Use the shielding-window level (used by lock screen / screen saver)
        // — it is guaranteed to composite above the menu bar. `.screenSaver`
        // (1000) works on some macOS versions but not all; the shielding
        // level (≈ 2_147_483_631) is the only value that reliably draws over
        // the menu bar across Sonoma / Sequoia.
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]
        panel.ignoresMouseEvents = true
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.worksWhenModal = false
        panel.contentView = hostingView
    }

    // MARK: - Public API

    func show() {
        guard geometry.notchSafeFrame != nil else { return }
        hideTask?.cancel()
        hideTask = nil
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
        // Position *after* orderFront: macOS constrains frames of hidden
        // windows to `visibleFrame` (below the menu bar). Re-applying the
        // frame once the window is on-screen forces the system to honour
        // the screen-top origin we actually want.
        positionAtScreenTop()
        panel.ignoresMouseEvents = !viewModel.isExpanded
    }

    func hide() {
        guard panel.isVisible else { return }
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            // `Task.sleep` honours cancellation, so a concurrent `show()`
            // simply interrupts this and the window stays on screen.
            try? await Task.sleep(for: Self.hideTransitionDelay)
            guard !Task.isCancelled else { return }
            self?.panel.orderOut(nil)
        }
    }

    func updateLayout() {
        guard geometry.notchSafeFrame != nil else {
            hide()
            return
        }
        positionAtScreenTop()
    }

    // MARK: - Private

    /// Anchor the panel so its top edge matches the screen top. The SwiftUI
    /// layer keeps the top `notchHeight` pixels transparent so the physical
    /// cutout shows through; the pill hangs directly below that spacer.
    private func positionAtScreenTop() {
        guard geometry.notchSafeFrame != nil,
              let screen = geometry.activeScreen else { return }
        let originX = screen.frame.minX
        let width = screen.frame.width
        let originY = screen.frame.maxY - Self.panelHeight
        panel.setFrame(
            NSRect(x: originX, y: originY, width: width, height: Self.panelHeight),
            display: true,
            animate: false
        )
    }
}

/// SwiftUI's `.ignoresSafeArea` only affects the SwiftUI layer — the
/// backing `NSHostingView` still exposes non-zero safe area insets derived
/// from the underlying window, which in turn pushes the SwiftUI content
/// down when the window sits under the notch. Overriding the AppKit-side
/// insets to zero is the only way to anchor the bubble's top edge to the
/// screen top so it visually merges with the notch.
final class TopAlignedHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets()
    }
}
