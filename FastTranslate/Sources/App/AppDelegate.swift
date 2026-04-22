import Cocoa
import Carbon.HIToolbox

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var settings: AppSettings?
    private var menuBarController: MenuBarController?
    private var menuBarViewModel: TranslationViewModel?
    private var hotkeyService: GlobalHotkeyService?
    private var floatingPanel: FloatingTranslationPanel?
    private var coordinator: InlineTranslationCoordinator?
    private var broadcaster: TranslationActivityBroadcaster?
    private var notchOverlayVM: NotchOverlayViewModel?
    private var notchOverlayPanel: NotchOverlayPanel?
    private var screenGeometry: ScreenGeometryProviding?
    private var screenParamsObserver: NSObjectProtocol?
    private var workspaceActivationObserver: NSObjectProtocol?

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

        let geometry = ScreenGeometryService()
        self.screenGeometry = geometry

        let coordinator = InlineTranslationCoordinator(
            settings: settings,
            capture: SelectionCaptureService(),
            panel: panel,
            providerFactory: OllamaProviderFactory(settings: settings),
            geometry: geometry
        )
        self.coordinator = coordinator

        // Hoist the menu bar view model out of `TranslateView` so that the
        // notch overlay broadcaster (and any future cross-cutting observers)
        // can subscribe to the same instance that drives the popover UI.
        let provider = OllamaProvider(baseURL: settings.ollamaURL, model: settings.selectedModel)
        let menuBarVM = TranslationViewModel(provider: provider, settings: settings)
        self.menuBarViewModel = menuBarVM

        menuBarController = MenuBarController(settings: settings, viewModel: menuBarVM)
        hotkeyService = GlobalHotkeyService(hotkeys: [
            // Cmd+Shift+T — trigger inline translation of the current selection.
            .init(
                keyCode: UInt32(kVK_ANSI_T),
                modifiers: UInt32(cmdKey | shiftKey)
            ) { [weak coordinator] in
                Task { await coordinator?.trigger() }
            },
            // Cmd+Shift+L — cycle the target language and flash a toast in
            // the notch overlay so the user can see what they landed on.
            .init(
                keyCode: UInt32(kVK_ANSI_L),
                modifiers: UInt32(cmdKey | shiftKey)
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.cycleTargetLanguage()
                }
            }
        ])

        // Aggregate both view models into a single activity stream. This is
        // what the notch overlay (and potentially other future consumers)
        // subscribe to, rather than touching the individual view models.
        let broadcaster = TranslationActivityBroadcaster(
            menuBarVM: menuBarVM,
            inlineVM: panel.viewModel
        )
        self.broadcaster = broadcaster

        // Notch overlay is created whenever the active display has a
        // notch. The `notchOverlayEnabled` setting is consulted at runtime
        // inside `observeBroadcaster` — creating the subsystem eagerly
        // means toggling the setting OFF→ON no longer requires a restart.
        if geometry.hasNotch {
            let notchVM = NotchOverlayViewModel()
            let inlineVM = panel.viewModel
            let notchPanel = NotchOverlayPanel(
                viewModel: notchVM,
                geometry: geometry,
                onCopy: { [weak notchVM] in
                    guard let notchVM else { return }
                    let text: String
                    switch notchVM.activity.state {
                    case .streaming(_, let translated),
                         .done(_, let translated):
                        text = translated
                    default:
                        return
                    }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    notchVM.dismissManually()
                },
                onReplace: { [weak inlineVM, weak notchVM] in
                    guard let inlineVM, let notchVM else { return }
                    // Replace only makes sense for the inline originator —
                    // the view hides the button otherwise, but double-check.
                    guard notchVM.activity.originator == .inline else {
                        notchVM.dismissManually()
                        return
                    }
                    notchVM.dismissManually()
                    Task { await inlineVM.replaceSelection() }
                },
                onDismiss: { [weak notchVM] in
                    notchVM?.dismissManually()
                }
            )
            self.notchOverlayVM = notchVM
            self.notchOverlayPanel = notchPanel

            // Bridge broadcaster → notch view model. Reading `activity`
            // inside `withObservationTracking` registers us for updates,
            // and we re-subscribe inside the `onChange` closure to keep the
            // chain alive. The panel show/hide reacts to the resulting
            // `isExpanded` / activity state.
            observeBroadcaster(broadcaster, notchVM: notchVM, notchPanel: notchPanel)
            installScreenObservers()
        }
    }

    /// Advance `targetLanguage` to the next entry in `Language.targets`
    /// and flash a toast in the notch overlay. No-op if settings aren't
    /// ready yet; the toast is silently skipped when the display has no
    /// notch (the language still cycles).
    private func cycleTargetLanguage() {
        guard let settings else { return }
        let targets = Language.targets
        guard !targets.isEmpty else { return }
        let next: Language
        if let idx = targets.firstIndex(of: settings.targetLanguage) {
            next = targets[(idx + 1) % targets.count]
        } else {
            next = targets[0]
        }
        settings.targetLanguage = next
        notchOverlayVM?.showToast(.targetLanguage(next))
    }

    /// Observe system-level events that can invalidate the notch overlay's
    /// position or make it impossible to show (fullscreen apps hide the
    /// notch area, display reconfigurations move screens around, etc.).
    private func installScreenObservers() {
        // Display reconfiguration — recompute the notch frame and update
        // the panel's position. If the active screen no longer has a notch
        // (e.g. external display became primary) we hide the panel.
        screenParamsObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                      let geometry = self.screenGeometry,
                      let notchPanel = self.notchOverlayPanel else { return }
                if geometry.hasNotch {
                    notchPanel.updateLayout()
                } else {
                    notchPanel.hide()
                }
            }
        }

        // Frontmost app changed — covers the fullscreen-video case: when an
        // app goes fullscreen on the notched display, the system hides the
        // menu bar and the notch itself. We mirror that by hiding our
        // overlay. When focus returns to a non-fullscreen app (menu bar
        // visible again) we restore whatever activity is current.
        workspaceActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self,
                      let geometry = self.screenGeometry,
                      let notchPanel = self.notchOverlayPanel,
                      let notchVM = self.notchOverlayVM else { return }
                if geometry.hasNotch {
                    // Re-sync visibility with whatever's currently on-screen
                    // — translation activity or a live toast.
                    if notchVM.isPresenting {
                        notchPanel.updateLayout()
                        notchPanel.show()
                    } else {
                        notchPanel.hide()
                    }
                } else {
                    notchPanel.hide()
                }
            }
        }
    }

    /// Recursive observation of the broadcaster's `activity` and the user's
    /// `notchOverlayEnabled` preference. When the toggle flips off at
    /// runtime we must hide any existing overlay — otherwise the notch pill
    /// and the floating panel end up on screen simultaneously.
    private func observeBroadcaster(
        _ broadcaster: TranslationActivityBroadcaster,
        notchVM: NotchOverlayViewModel,
        notchPanel: NotchOverlayPanel
    ) {
        _ = withObservationTracking {
            _ = broadcaster.activity
            _ = self.settings?.notchOverlayEnabled
            // Track the toast so language-cycle toasts (fired outside the
            // broadcaster's activity stream) also drive panel visibility.
            _ = notchVM.toast
        } onChange: { [weak self, weak broadcaster, weak notchVM, weak notchPanel] in
            Task { @MainActor [weak self] in
                guard let self,
                      let broadcaster,
                      let notchVM,
                      let notchPanel,
                      let settings = self.settings else { return }

                // Toggle disabled — suppress overlay entirely regardless of
                // what the broadcaster currently holds.
                guard settings.notchOverlayEnabled else {
                    notchPanel.hide()
                    self.observeBroadcaster(broadcaster, notchVM: notchVM, notchPanel: notchPanel)
                    return
                }

                notchVM.apply(broadcaster.activity)
                // `isPresenting` rolls up translation activity + toast so
                // either source can drive show/hide without duplicated logic.
                if notchVM.isPresenting {
                    notchPanel.updateLayout()
                    notchPanel.show()
                } else {
                    notchPanel.hide()
                }
                self.observeBroadcaster(broadcaster, notchVM: notchVM, notchPanel: notchPanel)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let screenParamsObserver {
            NotificationCenter.default.removeObserver(screenParamsObserver)
        }
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceActivationObserver)
        }
        screenParamsObserver = nil
        workspaceActivationObserver = nil

        hotkeyService = nil
        coordinator = nil
        notchOverlayPanel = nil
        notchOverlayVM = nil
        screenGeometry = nil
        broadcaster = nil
        menuBarController = nil
        menuBarViewModel = nil
        floatingPanel = nil
        settings = nil
    }
}
