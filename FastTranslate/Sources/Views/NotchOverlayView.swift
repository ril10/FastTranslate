import SwiftUI

/// SwiftUI content hosted inside `NotchOverlayPanel`. A transparent spacer
/// the height of the notch reserves the physical cutout area; a rounded
/// rectangle pill hangs directly below it. Appearance/dismissal is driven
/// by `.transition(.scale + .opacity)` anchored at the top so the pill
/// reads as growing out of (and retracting into) the notch.
struct NotchOverlayView: View {

    @Bindable var viewModel: NotchOverlayViewModel

    /// Physical notch dimensions on the active display; the transparent
    /// spacer at the top of the bubble uses the height to let the cutout
    /// show through, and the width drives the collapsed pill's baseline.
    let notchSize: CGSize

    let onCopy: () -> Void
    let onReplace: () -> Void
    let onDismiss: () -> Void

    private var collapsedExtraWidth: CGFloat { 120 }
    private var expandedWidth: CGFloat { 560 }
    private var bubbleCornerRadius: CGFloat { 16 }

    /// Rubbery spring used for the bubble appearance — noticeable overshoot.
    private var appearSpring: Animation {
        .spring(response: 0.5, dampingFraction: 0.62, blendDuration: 0)
    }

    /// Smoother, near-critically damped curve for dismissal — no bounce,
    /// just a gentle shrink back into the notch.
    private var dismissSpring: Animation {
        .spring(response: 0.38, dampingFraction: 0.95, blendDuration: 0)
    }

    private var resizeSpring: Animation {
        .spring(response: 0.42, dampingFraction: 0.72, blendDuration: 0)
    }

    private var isVisible: Bool { viewModel.isPresenting }

    var body: some View {
        ZStack(alignment: .top) {
            // Transparent filler that claims the whole hosting view so the
            // bubble can anchor to the very top edge with `.top` alignment.
            Color.clear

            Group {
                if isVisible {
                    bubble
                        .transition(
                            .asymmetric(
                                insertion: AnyTransition
                                    .scale(scale: 0.08, anchor: .top)
                                    .combined(with: .opacity)
                                    .animation(appearSpring),
                                removal: AnyTransition
                                    .scale(scale: 0.1, anchor: .top)
                                    .combined(with: .opacity)
                                    .animation(dismissSpring)
                            )
                        )
                }
            }
            .animation(resizeSpring, value: viewModel.isExpanded)
            .animation(resizeSpring, value: viewModel.activity)
        }
        // Width is driven by hosting view bounds (full screen width); height
        // is the fixed panel height.
        .frame(maxWidth: .infinity)
        .frame(height: NotchOverlayPanel.panelHeight)
        .ignoresSafeArea(.all)
    }

    // MARK: - Bubble

    private var bubble: some View {
        VStack(spacing: 0) {
            // Transparent spacer the height of the physical notch so the
            // cutout shows through — the pill hangs directly under it.
            Color.clear.frame(height: notchSize.height)

            content
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(width: currentWidth)
                .background(bubbleBackground)
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var currentWidth: CGFloat {
        if viewModel.toast != nil {
            return toastWidth
        }
        return viewModel.isExpanded
            ? expandedWidth
            : notchSize.width + collapsedExtraWidth
    }

    private var toastWidth: CGFloat { notchSize.width + collapsedExtraWidth }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let toast = viewModel.toast {
            toastContent(toast)
        } else {
            switch viewModel.activity.state {
            case .idle:
                EmptyView()
            case .translating:
                collapsedContent
            case .streaming(let source, let translated):
                expandedContent(source: source, translated: translated, isError: false)
            case .done(let source, let translated):
                expandedContent(source: source, translated: translated, isError: false)
            case .error(let source):
                expandedContent(source: source, translated: "Translation failed", isError: true)
            }
        }
    }

    @ViewBuilder
    private func toastContent(_ toast: NotchToast) -> some View {
        switch toast {
        case .targetLanguage(let language):
            HStack(spacing: 8) {
                Text(language.flag)
                    .font(.system(size: 18))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Target language")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                    Text(language.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(height: 30)
        }
    }

    private var collapsedContent: some View {
        HStack(spacing: 6) {
            Image(systemName: "translate")
                .font(.system(size: 11, weight: .medium))
            Text("Translating")
                .font(.system(size: 11, weight: .medium))
            PulseDot()
        }
        .foregroundStyle(.white)
        .frame(height: 18)
    }

    private func expandedContent(source: String, translated: String, isError: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    if !source.isEmpty {
                        Text(source)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }
                    Text(translated)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isError ? Color.red : .white)
                        .lineLimit(4)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if !isError && !translated.isEmpty {
                HStack(spacing: 12) {
                    Spacer()
                    if viewModel.activity.originator == .inline {
                        actionButton(title: "Replace", systemImage: "text.insert", action: onReplace)
                    }
                    actionButton(title: "Copy", systemImage: "doc.on.doc", action: onCopy)
                }
            }
        }
    }

    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background

    private var bubbleBackground: some View {
        RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
            .fill(Color.black.opacity(0.92))
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
    }
}

// MARK: - Pulse indicator

private struct PulseDot: View {
    @State private var scale: CGFloat = 0.6

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 6, height: 6)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    scale = 1.0
                }
            }
    }
}
