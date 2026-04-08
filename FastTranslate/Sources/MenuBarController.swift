import Cocoa
import SwiftUI

final class MenuBarController {

    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var eventMonitor: EventMonitor?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Настраиваем popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 320)
        popover.behavior = .transient
        popover.animates = true

        let contentView = TranslateView()
        popover.contentViewController = NSHostingController(rootView: contentView)

        // Иконка в menu bar (после инициализации всех stored properties)
        if let button = statusItem.button {
            button.title = "翻"
            button.action = #selector(togglePopover)
            button.target = self
        }

        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.isShown else { return }
            self.closePopover()
        }
    }

    @objc func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        eventMonitor?.start()
    }

    private func closePopover() {
        popover.performClose(nil)
        eventMonitor?.stop()
    }

    // MARK: - Custom Menu Bar Icon

    private static func makeMenuBarIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let color = CGColor(gray: 0, alpha: 1)

            // --- Back bubble (left-bottom, semi-transparent) ---
            ctx.setFillColor(CGColor(gray: 0, alpha: 0.5))

            // Rounded rect
            let backBody = CGRect(x: 0, y: 2, width: 11, height: 9)
            ctx.addPath(CGPath(roundedRect: backBody, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
            ctx.fillPath()

            // Tail (bottom-left)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 1.5, y: 11))
            ctx.addLine(to: CGPoint(x: 0, y: 14))
            ctx.addLine(to: CGPoint(x: 4.5, y: 11))
            ctx.closePath()
            ctx.fillPath()

            // --- Front bubble (right-top, full opacity) ---
            ctx.setFillColor(color)

            let frontBody = CGRect(x: 7, y: 5, width: 11, height: 9)
            ctx.addPath(CGPath(roundedRect: frontBody, cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
            ctx.fillPath()

            // Tail (top-right)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 14.5, y: 5))
            ctx.addLine(to: CGPoint(x: 18, y: 2))
            ctx.addLine(to: CGPoint(x: 12, y: 5))
            ctx.closePath()
            ctx.fillPath()

            // --- Two horizontal lines inside front bubble (text symbol) ---
            ctx.setFillColor(CGColor(gray: 1, alpha: 0.9))
            ctx.fill(CGRect(x: 9, y: 7.5, width: 7, height: 1.5))
            ctx.fill(CGRect(x: 9, y: 10.5, width: 5, height: 1.5))

            return true
        }
        image.isTemplate = true
        return image
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
