import Cocoa

@MainActor
final class InlineTranslationCoordinator {

    private let settings: AppSettings
    private let capture: SelectionCapturing
    private let panel: FloatingTranslationPanel
    private let providerFactory: TranslationProviderFactory
    private let geometry: ScreenGeometryProviding

    init(
        settings: AppSettings,
        capture: SelectionCapturing,
        panel: FloatingTranslationPanel,
        providerFactory: TranslationProviderFactory,
        geometry: ScreenGeometryProviding
    ) {
        self.settings = settings
        self.capture = capture
        self.panel = panel
        self.providerFactory = providerFactory
        self.geometry = geometry
    }

    func trigger() async {
        guard settings.inlineTranslation else { return }
        let text = await capture.captureSelectedText()
        guard !text.isEmpty else { return }

        let provider = providerFactory.make()

        // Notch overlay and floating panel are mutually exclusive. Notch
        // wins when the user opted in *and* the display actually has a
        // notch — otherwise the floating panel is the only visible UI.
        let useNotch = settings.notchOverlayEnabled && geometry.hasNotch
        if useNotch {
            // Translation still flows through the shared VM so the
            // broadcaster drives the notch overlay. We intentionally do
            // NOT call `panel.show(...)` — that would create the floating
            // NSPanel and both UIs would end up visible simultaneously.
            panel.dismiss()
            panel.viewModel.reset()
            panel.viewModel.sourceText = text
            panel.viewModel.translate(with: provider)
        } else {
            let location = NSEvent.mouseLocation
            panel.show(text: text, near: location, provider: provider)
        }
    }
}
