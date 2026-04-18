import Cocoa
import SwiftUI

@MainActor
final class MenuBarController {

    private var statusItem: NSStatusItem
    private var panel: MenuBarPanel
    private var eventMonitor: EventMonitor?
    private let viewModel: TranslationViewModel

    init(settings: AppSettings, viewModel: TranslationViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Build the SwiftUI content and wrap it in an NSHostingController so
        // the borderless panel can host it the same way NSPopover did. The
        // view model is owned by `AppDelegate` and injected here so that
        // other observers (e.g. the notch overlay broadcaster) can share it.
        let contentView = TranslateView(settings: settings, viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)
        panel = MenuBarPanel(contentViewController: hostingController)

        // Menu bar icon (after all stored properties are initialized)
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.action = #selector(togglePopover)
            button.target = self
        }

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            // EventMonitor callbacks arrive on the main thread, but the
            // closure itself is non-isolated. Hop to the main actor to touch
            // MenuBarController state safely.
            Task { @MainActor in
                guard let self, self.panel.isShown else { return }
                self.closePopover()
            }
        }
    }

    @objc func togglePopover() {
        if panel.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        // Each open starts from a clean slate — users expect the popover to
        // forget the previous translation, not resume it.
        viewModel.send(.clearAll)
        panel.show(relativeTo: button)
        eventMonitor?.start()
    }

    private func closePopover() {
        panel.close()
        eventMonitor?.stop()
    }

}

// MARK: - EventMonitor

final class EventMonitor {
    private var monitor: Any?
    private let mask: NSEvent.EventTypeMask
    private let handler: (NSEvent?) -> Void

    init(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent?) -> Void) {
        self.mask = mask
        self.handler = handler
    }

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
    }

    func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }

    deinit { stop() }
}
