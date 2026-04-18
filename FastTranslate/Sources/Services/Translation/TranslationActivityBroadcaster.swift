import Foundation
import Observation
import os

/// Aggregates the observable state of the menu bar popover view model and the
/// inline floating panel view model into a single `TranslationActivity`
/// snapshot. Consumers (e.g. the notch overlay view model) can subscribe to
/// the broadcaster via `withObservationTracking` and receive coalesced
/// updates.
///
/// Priority: inline activity wins over menu bar activity whenever the inline
/// flow is not idle. This matches user intent — if the user just pressed the
/// global hotkey, we don't want a stale popover translation to compete with
/// the inline result.
///
/// Token streaming from Ollama can fire several updates per animation frame.
/// To keep the notch overlay smooth, intermediate `streaming` states are
/// throttled to at most one push per 33ms (~30 FPS). Terminal states
/// (`idle`, `done`, `error`) bypass the throttle so the UI collapses or
/// finalises immediately.
@MainActor
@Observable
final class TranslationActivityBroadcaster {

    private(set) var activity: TranslationActivity = .idle

    private let menuBarVM: TranslationViewModel
    private let inlineVM: FloatingTranslationViewModel
    private var pendingUpdate: Task<Void, Never>?
    private var lastPushWasThrottled: Bool = false

    /// 33ms ≈ 30 FPS. Lower than typical Ollama token cadence, high enough
    /// that the UI still reads as "streaming".
    private let throttleNanos: UInt64 = 33_000_000

    private let logger = Logger(
        subsystem: "com.fasttranslate.app",
        category: "TranslationActivityBroadcaster"
    )

    init(menuBarVM: TranslationViewModel, inlineVM: FloatingTranslationViewModel) {
        self.menuBarVM = menuBarVM
        self.inlineVM = inlineVM
        // Prime activity and both tracking loops.
        activity = computeActivity()
        trackInline()
        trackMenuBar()
    }

    deinit {
        // `Task` captures `self` weakly above, so there is nothing to cancel
        // explicitly — pending tasks simply no-op after deallocation.
    }

    // MARK: - Observation tracking

    private func trackInline() {
        _ = withObservationTracking {
            // Read every property we care about so Observation records them.
            _ = inlineVM.sourceText
            _ = inlineVM.translatedText
            _ = inlineVM.isTranslating
            _ = inlineVM.hasError
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scheduleUpdate()
                self.trackInline()
            }
        }
    }

    private func trackMenuBar() {
        _ = withObservationTracking {
            _ = menuBarVM.inputText
            _ = menuBarVM.outputText
            _ = menuBarVM.translationState
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.scheduleUpdate()
                self.trackMenuBar()
            }
        }
    }

    // MARK: - Update scheduling

    private func scheduleUpdate() {
        let next = computeActivity()

        // Terminal states (idle / done / error) bypass the throttle so the UI
        // reacts immediately when a translation finishes or the user clears.
        if isTerminal(next.state) {
            pendingUpdate?.cancel()
            pendingUpdate = nil
            push(next)
            return
        }

        // A throttled task is already in flight — it will observe the latest
        // state when it fires, so we do not schedule another one.
        if pendingUpdate != nil { return }

        pendingUpdate = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.throttleNanos ?? 33_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.pendingUpdate = nil
            // Re-read the latest activity after the throttle window closes.
            self.push(self.computeActivity())
        }
    }

    private func push(_ next: TranslationActivity) {
        guard next != activity else { return }
        activity = next
        logger.debug("activity -> \(String(describing: next.state), privacy: .public), origin=\(next.originator.rawValue, privacy: .public)")
    }

    private func isTerminal(_ state: TranslationActivityState) -> Bool {
        switch state {
        case .idle, .done, .error: return true
        case .translating, .streaming: return false
        }
    }

    // MARK: - State derivation

    private func computeActivity() -> TranslationActivity {
        let inline = inlineState()
        // Inline takes priority whenever it has anything to show. Otherwise
        // we fall back to the menu bar popover state.
        if case .idle = inline.state {
            return menuBarActivity()
        }
        return inline
    }

    private func inlineState() -> TranslationActivity {
        let source = inlineVM.sourceText
        let translated = inlineVM.translatedText

        if inlineVM.hasError {
            return TranslationActivity(state: .error(source: source), originator: .inline)
        }
        if inlineVM.isTranslating {
            if translated.isEmpty {
                return TranslationActivity(state: .translating(source: source), originator: .inline)
            }
            return TranslationActivity(
                state: .streaming(source: source, translated: translated),
                originator: .inline
            )
        }
        if !translated.isEmpty {
            return TranslationActivity(
                state: .done(source: source, translated: translated),
                originator: .inline
            )
        }
        return TranslationActivity(state: .idle, originator: .inline)
    }

    private func menuBarActivity() -> TranslationActivity {
        let source = menuBarVM.inputText
        let translated = menuBarVM.outputText

        switch menuBarVM.translationState {
        case .idle:
            return .idle
        case .translating:
            if translated.isEmpty {
                return TranslationActivity(state: .translating(source: source), originator: .menuBar)
            }
            return TranslationActivity(
                state: .streaming(source: source, translated: translated),
                originator: .menuBar
            )
        case .done:
            return TranslationActivity(
                state: .done(source: source, translated: translated),
                originator: .menuBar
            )
        case .error:
            return TranslationActivity(state: .error(source: source), originator: .menuBar)
        }
    }
}
