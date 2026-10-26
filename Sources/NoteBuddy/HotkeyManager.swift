import Carbon

/// Registers the global Cmd+Shift+Space hotkey. Carbon hotkeys need no extra permission.
final class HotkeyManager {
    private let onPress: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(onPress: @escaping @MainActor () -> Void) {
        self.onPress = onPress

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let action = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue().onPress
                Task { @MainActor in action() }
                return noErr
            },
            1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        let id = EventHotKeyID(signature: OSType(0x4E42_4459), id: 1) // "NBDY"
        RegisterEventHotKey(
            UInt32(kVK_Space), UInt32(cmdKey | shiftKey), id,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
