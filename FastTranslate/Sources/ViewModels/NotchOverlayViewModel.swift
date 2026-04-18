import Foundation
import Observation

/// Drives the notch overlay UI. The overlay has two visual modes:
///
/// - **Collapsed**: a narrow capsule that sits under the notch and pulses
///   while a translation is in-flight (or remains invisible when idle).
/// - **Expanded**: a wider panel that displays the source text and streaming
///   translation, matching the content that is simultaneously rendered in
///   the inline floating panel or menu bar popover.
///
/// The view model purposefully carries a very small amount of state — it is
/// a render-side projection of `TranslationActivity` that the
/// `TranslationActivityBroadcaster` produces.
@MainActor
@Observable
final class NotchOverlayViewModel {

    var activity: TranslationActivity = .idle
    var isExpanded: Bool = false

    /// Set when the user manually closes the overlay. Suppresses further
    /// updates from the broadcaster until a new translation session begins
    /// (broadcaster transitions idle → translating).
    private(set) var manuallyDismissed: Bool = false

    func apply(_ activity: TranslationActivity) {
        // A new translation session lifts the manual-dismiss suppression so
        // the user doesn't have to toggle a setting to see the next result.
        if case .translating = activity.state, case .idle = self.activity.state {
            manuallyDismissed = false
        }

        guard !manuallyDismissed else { return }

        self.activity = activity
        switch activity.state {
        case .idle, .translating:
            isExpanded = false
        case .streaming, .done, .error:
            isExpanded = true
        }
    }

    func dismissManually() {
        manuallyDismissed = true
        activity = .idle
        isExpanded = false
    }
}
