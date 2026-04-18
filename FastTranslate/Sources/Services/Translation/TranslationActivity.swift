import Foundation

/// Represents the lifecycle of a single translation attempt, regardless of
/// whether it originated from the menu bar popover or the inline floating
/// panel. The state machine is designed to drive UI affordances such as the
/// notch overlay (which collapses when idle, pulses while a request is in
/// flight, and expands to show streaming output once tokens start arriving).
enum TranslationActivityState: Equatable, Sendable {
    case idle
    case translating(source: String)
    case streaming(source: String, translated: String)
    case done(source: String, translated: String)
    case error(source: String)
}

/// A snapshot of the currently active translation together with its origin.
/// `originator` lets consumers distinguish between the inline flow (global
/// hotkey-triggered floating panel) and the menu bar popover flow, which is
/// important for presentation decisions — for example, the notch overlay
/// prioritises inline activity over menu bar activity.
struct TranslationActivity: Equatable, Sendable {
    let state: TranslationActivityState
    let originator: Originator

    enum Originator: String, Sendable {
        case menuBar
        case inline
    }

    static let idle = TranslationActivity(state: .idle, originator: .menuBar)
}
