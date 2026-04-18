import Cocoa
import Carbon.HIToolbox

final class GlobalHotkeyService {

    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var retainedSelf: Unmanaged<GlobalHotkeyService>?
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        registerHotkey()
    }

    deinit {
        if let hotKey = hotKeyRef {
            UnregisterEventHotKey(hotKey)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        retainedSelf?.release()
    }

    // MARK: - Private

    private func registerHotkey() {
        // Cmd+Shift+T
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4654_5248) // "FTRH"
        hotKeyID.id = 1

        let modifiers = UInt32(cmdKey | shiftKey)
        let keyCode = UInt32(kVK_ANSI_T)

        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard status == noErr else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, _, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userData).takeUnretainedValue()
            service.onTrigger()
            return noErr
        }

        retainedSelf = Unmanaged.passRetained(self)
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, retainedSelf!.toOpaque(), &eventHandler)
    }
}
