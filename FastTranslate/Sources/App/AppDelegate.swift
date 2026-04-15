import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {

    private var settings: AppSettings?
    private var menuBarController: MenuBarController?
    private var hotkeyService: GlobalHotkeyService?
    private var floatingPanel: FloatingTranslationPanel?
    private var coordinator: InlineTranslationCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let settings = AppSettings(storage: UserDefaultsStorage())
        self.settings = settings

        let panel = FloatingTranslationPanel(
            settings: settings,
            textReplacer: TextReplacementService(),
            permissions: AccessibilityPermissionService()
        )
        floatingPanel = panel

        let coordinator = InlineTranslationCoordinator(
            settings: settings,
            capture: SelectionCaptureService(),
            panel: panel,
            providerFactory: OllamaProviderFactory(settings: settings)
        )
        self.coordinator = coordinator

        menuBarController = MenuBarController(settings: settings)
        hotkeyService = GlobalHotkeyService { [weak coordinator] in
            Task { await coordinator?.trigger() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService = nil
        coordinator = nil
        menuBarController = nil
        floatingPanel = nil
        settings = nil
    }
}
