import Cocoa

/// Abstraction for querying screen geometry relevant to the notch overlay.
/// Factoring this behind a protocol lets us stub screen state in tests and
/// on hardware without a notch during development.
@MainActor
protocol ScreenGeometryProviding {
    /// The rectangle occupied by the physical notch on the active screen,
    /// expressed in the standard AppKit bottom-left screen coordinate space.
    /// Returns `nil` on displays without a notch.
    var notchSafeFrame: NSRect? { get }

    /// The screen that currently hosts the menu bar / active window.
    var activeScreen: NSScreen? { get }

    /// `true` when the active screen reports a non-zero top safe area inset,
    /// which is the documented signal that the display carries a notch.
    var hasNotch: Bool { get }
}

@MainActor
final class ScreenGeometryService: ScreenGeometryProviding {

    /// Prefer the physical-notch screen over `NSScreen.main`. When an
    /// external monitor is the key-window screen, `NSScreen.main` points
    /// there, but the overlay must follow the notch — which is always on
    /// the built-in MacBook display.
    var activeScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
    }

    var hasNotch: Bool {
        guard let screen = activeScreen else { return false }
        return screen.safeAreaInsets.top > 0
    }

    /// Computes the notch rectangle by taking the gap between the left and
    /// right auxiliary top areas exposed by macOS 12+. The left auxiliary
    /// area spans from the left edge of the screen to the start of the
    /// notch; the right auxiliary area spans from the end of the notch to
    /// the right edge. The notch itself sits in the gap between them at the
    /// very top of the screen frame.
    var notchSafeFrame: NSRect? {
        guard let screen = activeScreen, hasNotch else { return nil }

        let leftAux = screen.auxiliaryTopLeftArea ?? .zero
        let rightAux = screen.auxiliaryTopRightArea ?? .zero
        let screenFrame = screen.frame
        let notchHeight = screen.safeAreaInsets.top

        let notchMinX = leftAux.maxX
        let notchMaxX = rightAux.minX
        guard notchMaxX > notchMinX else { return nil }

        // AppKit screen coordinates put the origin at the bottom-left, so the
        // notch — which lives at the top of the display — has a `y` equal to
        // `maxY - notchHeight`.
        return NSRect(
            x: notchMinX,
            y: screenFrame.maxY - notchHeight,
            width: notchMaxX - notchMinX,
            height: notchHeight
        )
    }
}
