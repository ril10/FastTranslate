import Cocoa
import Carbon.HIToolbox

/// Registers one or more global keyboard shortcuts with Carbon's
/// `RegisterEventHotKey` and dispatches presses to per-hotkey closures.
/// A single app-level event handler multiplexes events to the correct
/// action by matching `EventHotKeyID.id`.
final class GlobalHotkeyService {

    struct Hotkey {
        let keyCode: UInt32
        let modifiers: UInt32
        let action: () -> Void
    }

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var actionsByID: [UInt32: () -> Void] = [:]
    private var retainedSelf: Unmanaged<GlobalHotkeyService>?

    /// Four-char signature shared by every hotkey we register ("FTRH").
    private static let signature = OSType(0x4654_5248)

    init(hotkeys: [Hotkey]) {
        register(hotkeys)
    }

    deinit {
        for ref in hotKeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        retainedSelf?.release()
    }

    // MARK: - Private

    private func register(_ hotkeys: [Hotkey]) {
        for (index, hotkey) in hotkeys.enumerated() {
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            actionsByID[hotKeyID.id] = hotkey.action

            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                hotkey.keyCode,
                hotkey.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            guard status == noErr else { continue }
            hotKeyRefs.append(ref)
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userData).takeUnretainedValue()
            service.actionsByID[hotKeyID.id]?()
            return noErr
        }

        retainedSelf = Unmanaged.passRetained(self)
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            retainedSelf!.toOpaque(),
            &eventHandler
        )
    }
}
