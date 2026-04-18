import Cocoa
import SwiftUI
import Observation

@MainActor
final class FloatingTranslationPanel {

    private var panel: NSPanel?
    private var hostView: NSHostingView<FloatingTranslationView>?
    /// Exposed so cross-cutting observers (e.g. `TranslationActivityBroadcaster`)
    /// can subscribe to the inline translation state from a single owner at
    /// the app root. The panel itself is the only mutator.
    let viewModel: FloatingTranslationViewModel
    private var eventMonitor: Any?
    private var resizeTask: Task<Void, Never>?

    init(
        settings: AppSettings,
        textReplacer: TextReplacing,
        permissions: AccessibilityPermissionChecking
    ) {
        self.viewModel = FloatingTranslationViewModel(
            settings: settings,
            textReplacer: textReplacer,
            permissions: permissions
        )
    }

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
            FloatingTranslationView(
                viewModel: viewModel,
                onDismiss: { [weak self] in
                    self?.dismiss()
                },
                onReplace: { [weak self] in
                    guard let self else { return }
                    let vm = self.viewModel
                    self.dismiss()
                    Task { await vm.replaceSelection() }
                },
                onTranslatedTextChanged: { [weak self] in
                    self?.scheduleResize()
                }
            )
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

        let fittingSize = hostView.fittingSize
        let initialHeight = min(max(fittingSize.height, 80), 400)
        panel.setContentSize(NSSize(width: 340, height: initialHeight))

        let origin = NSPoint(x: point.x - 170, y: point.y - initialHeight - 10)
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()

        self.panel = panel

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.dismiss()
        }

        viewModel.translate(with: provider)
    }

    // MARK: - Private

    private func scheduleResize() {
        guard resizeTask == nil else { return }
        resizeTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            self?.resizeToFit()
            self?.resizeTask = nil
        }
    }

    private func resizeToFit() {
        guard let panel, let hostView else { return }
        let fittingSize = hostView.fittingSize
        let newHeight = min(max(fittingSize.height, 80), 400)
        let oldFrame = panel.frame

        let newFrame = NSRect(
            x: oldFrame.origin.x,
            y: oldFrame.origin.y - (newHeight - oldFrame.height),
            width: 340,
            height: newHeight
        )
        panel.setFrame(newFrame, display: true, animate: false)
    }

    func dismiss() {
        resizeTask?.cancel()
        resizeTask = nil
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
@Observable
final class FloatingTranslationViewModel {

    var sourceText: String = ""
    var translatedText: String = ""
    var isTranslating: Bool = false
    var hasError: Bool = false
    var isReplacing: Bool = false

    private let settings: AppSettings
    private let textReplacer: TextReplacing
    private let permissions: AccessibilityPermissionChecking
    private var currentTask: Task<Void, Never>?

    init(
        settings: AppSettings,
        textReplacer: TextReplacing,
        permissions: AccessibilityPermissionChecking
    ) {
        self.settings = settings
        self.textReplacer = textReplacer
        self.permissions = permissions
    }

    func reset() {
        sourceText = ""
        translatedText = ""
        isTranslating = false
        hasError = false
        isReplacing = false
        currentTask?.cancel()
    }

    func replaceSelection() async {
        guard !translatedText.isEmpty, !isReplacing else { return }
        guard permissions.isTrusted else {
            permissions.promptIfNeeded()
            return
        }
        isReplacing = true
        await textReplacer.replaceSelection(with: translatedText)
        isReplacing = false
    }

    func translate(with provider: TranslationProvider) {
        guard !sourceText.isEmpty else { return }

        isTranslating = true
        hasError = false
        translatedText = ""

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

    @Bindable var viewModel: FloatingTranslationViewModel
    let onDismiss: () -> Void
    let onReplace: () -> Void
    let onTranslatedTextChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
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

            if !viewModel.translatedText.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        onReplace()
                    } label: {
                        Label("Replace", systemImage: "text.insert")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(viewModel.isTranslating || viewModel.isReplacing)

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
        .onChange(of: viewModel.translatedText) { _, _ in
            onTranslatedTextChanged()
        }
    }
}
