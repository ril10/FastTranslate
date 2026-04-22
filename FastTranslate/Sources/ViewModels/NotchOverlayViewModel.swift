import Foundation
import Observation

/// Transient piece of content pushed to the notch overlay that isn't tied
/// to a translation lifecycle — e.g. a confirmation when the user cycles
/// the target language via the global hotkey. Toasts auto-dismiss after a
/// short duration and overlay whatever translation state is currently
/// active (without destroying it).
enum NotchToast: Equatable, Sendable {
    case targetLanguage(Language)
}

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
/// `TranslationActivityBroadcaster` produces, plus an optional transient
/// `toast` overlay.
@MainActor
@Observable
final class NotchOverlayViewModel {

    var activity: TranslationActivity = .idle
    var isExpanded: Bool = false
    private(set) var toast: NotchToast?

    /// Set when the user manually closes the overlay. Suppresses further
    /// updates from the broadcaster until a new translation session begins
    /// (broadcaster transitions idle → translating).
    private(set) var manuallyDismissed: Bool = false

    /// `true` whenever the overlay has something to show — either an
    /// active translation or a live toast. The panel observes this to
    /// decide show/hide without duplicating the state machine in its
    /// presentation layer.
    var isPresenting: Bool {
        if toast != nil { return true }
        if case .idle = activity.state { return false }
        return true
    }

    @ObservationIgnored private var toastDismissTask: Task<Void, Never>?

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

    /// Show a transient toast that auto-dismisses after `duration`. A
    /// pending toast is cancelled if a new one arrives so the newest toast
    /// always wins.
    func showToast(_ toast: NotchToast, duration: Duration = .milliseconds(1500)) {
        toastDismissTask?.cancel()
        self.toast = toast
        toastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    func dismissManually() {
        manuallyDismissed = true
        activity = .idle
        isExpanded = false
        toastDismissTask?.cancel()
        toast = nil
    }
}
