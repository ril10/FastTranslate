import Cocoa

@MainActor
final class InlineTranslationCoordinator {

    private let settings: AppSettings
    private let capture: SelectionCapturing
    private let panel: FloatingTranslationPanel
    private let providerFactory: TranslationProviderFactory

    init(
        settings: AppSettings,
        capture: SelectionCapturing,
        panel: FloatingTranslationPanel,
        providerFactory: TranslationProviderFactory
    ) {
        self.settings = settings
        self.capture = capture
        self.panel = panel
        self.providerFactory = providerFactory
    }

    func trigger() async {
        guard settings.inlineTranslation else { return }
        let text = await capture.captureSelectedText()
        guard !text.isEmpty else { return }
        let location = NSEvent.mouseLocation
        panel.show(text: text, near: location, provider: providerFactory.make())
    }
}
