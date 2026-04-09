import Cocoa
import SwiftUI
import Combine

@MainActor
final class FloatingTranslationPanel {

    private var panel: NSPanel?
    private var hostView: NSHostingView<FloatingTranslationView>?
    private var viewModel = FloatingTranslationViewModel()
    private var eventMonitor: Any?
    private var resizeCancellable: AnyCancellable?

    // MARK: - Public

    func show(text: String, near point: NSPoint, provider: TranslationProvider) {
        dismiss()

        viewModel.reset()
        viewModel.sourceText = text

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 120),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostView = NSHostingView(rootView:
            FloatingTranslationView(viewModel: viewModel, onDismiss: { [weak self] in
                self?.dismiss()
            })
        )
        hostView.wantsLayer = true
        hostView.layer?.cornerRadius = 12
        hostView.layer?.masksToBounds = true

        let wrapper = NSView()
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = .clear
        wrapper.addSubview(hostView)
        hostView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostView.topAnchor.constraint(equalTo: wrapper.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            hostView.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
        ])

        panel.contentView = wrapper
        self.hostView = hostView

        // Initial size from content
        let fittingSize = hostView.fittingSize
        let initialHeight = min(max(fittingSize.height, 80), 400)
        panel.setContentSize(NSSize(width: 340, height: initialHeight))

        // Position below cursor
        let origin = NSPoint(x: point.x - 170, y: point.y - initialHeight - 10)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()

        self.panel = panel

        // Resize panel as translation streams in
        resizeCancellable = viewModel.$translatedText
            .throttle(for: .milliseconds(100), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] _ in
                self?.resizeToFit()
            }

        // Click outside to dismiss
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }

        // Start translation
        viewModel.translate(with: provider)
    }

    // MARK: - Private

    private func resizeToFit() {
        guard let panel, let hostView else { return }
        let fittingSize = hostView.fittingSize
        let newHeight = min(max(fittingSize.height, 80), 400)
        let oldFrame = panel.frame

        // Grow upward (keep bottom-left, expand top)
        let newFrame = NSRect(
            x: oldFrame.origin.x,
            y: oldFrame.origin.y - (newHeight - oldFrame.height),
            width: 340,
            height: newHeight
        )
        panel.setFrame(newFrame, display: true, animate: false)
    }

    func dismiss() {
        resizeCancellable?.cancel()
        resizeCancellable = nil
        hostView = nil
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }
}

// MARK: - ViewModel

@MainActor
final class FloatingTranslationViewModel: ObservableObject {

    @Published var sourceText: String = ""
    @Published var translatedText: String = ""
    @Published var isTranslating: Bool = false
    @Published var hasError: Bool = false

    private var currentTask: Task<Void, Never>?

    func reset() {
        sourceText = ""
        translatedText = ""
        isTranslating = false
        hasError = false
        currentTask?.cancel()
    }

    func translate(with provider: TranslationProvider) {
        guard !sourceText.isEmpty else { return }

        isTranslating = true
        hasError = false
        translatedText = ""

        let settings = AppSettings.shared
        let text = sourceText
        let source = settings.sourceLanguage
        let target = settings.targetLanguage
        let stream = provider.translate(text: text, from: source, to: target)

        currentTask = Task {
            do {
                for try await token in stream {
                    guard !Task.isCancelled else { break }
                    translatedText += token
                }
            } catch {
                if !Task.isCancelled {
                    hasError = true
                }
            }
            isTranslating = false
        }
    }
}

// MARK: - SwiftUI View

struct FloatingTranslationView: View {

    @ObservedObject var viewModel: FloatingTranslationViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Image(systemName: "translate")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("FastTranslate")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if viewModel.isTranslating {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Translation
            if viewModel.hasError {
                Text("Translation failed")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            } else if viewModel.translatedText.isEmpty && viewModel.isTranslating {
                Text("Translating...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                Text(viewModel.translatedText)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            // Copy button
            if !viewModel.translatedText.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.translatedText, forType: .string)
                        onDismiss()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}
