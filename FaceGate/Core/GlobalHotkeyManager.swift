import Carbon
import AppKit

/// Handles global shortcut registrations using macOS Carbon APIs.
final class GlobalHotkeyManager {
    static let shared = GlobalHotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var isHandlerInstalled = false
    
    private init() {}
    
    /// Register the global hotkey to terminate FaceGate.
    func registerShortcut() {
        guard !isHandlerInstalled else { return }
        
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)
        
        // Setup handler callback once.
        let handler: EventHandlerUPP = { (nextHandler, event, userData) -> OSStatus in
            DispatchQueue.main.async {
                if let appDelegate = AppDelegate.shared {
                    appDelegate.isAuthorizedToQuit = true
                }
                NSApplication.shared.terminate(nil)
            }
            return noErr
        }
        
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            nil
        )
        isHandlerInstalled = true
        
        // Register current shortcut from configuration
        reRegisterShortcut()
    }
    
    /// Re-register the shortcut using the user's custom preferences.
    func reRegisterShortcut() {
        // Unregister the previous hotkey if it was registered
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        
        let defaults = UserDefaults.standard
        let isEnabled = defaults.object(forKey: FGConstants.emergencyKillEnabledKey) == nil || defaults.bool(forKey: FGConstants.emergencyKillEnabledKey)
        guard isEnabled else { return }
        
        let modifierStr = UserDefaults.standard.string(forKey: FGConstants.emergencyKillModifierKey) ?? "Command"
        let keyStr = UserDefaults.standard.string(forKey: FGConstants.emergencyKillTriggerKey) ?? "`"
        
        // Compulsory modifiers: Ctrl + Option
        var modifiers = UInt32(controlKey | optionKey)
        if modifierStr == "Command" {
            modifiers |= UInt32(cmdKey)
        } else if modifierStr == "Shift" {
            modifiers |= UInt32(shiftKey)
        }
        
        // Determine keyCode
        let keyCode: UInt32
        switch keyStr {
        case "Escape": keyCode = 53
        case "Space": keyCode = 49
        case "Q": keyCode = 12
        case "K": keyCode = 40
        case "X": keyCode = 7
        case "Delete": keyCode = 51
        default: keyCode = 50 // "`"
        }
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = UInt32(bigEndian: 0x46476b68) // "FGkh" signature
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            print("Failed to register custom global hotkey, status: \(status)")
        }
    }
}
