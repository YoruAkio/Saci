//
//  HotkeyManager.swift
//  Saci
//

import SwiftUI
import Carbon

// @note manages global hotkey registration
class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var retainedSelf: Unmanaged<HotkeyManager>?
    
    var onHotkeyPressed: (() -> Void)?
    
    private init() {
        // @note observe hotkey changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyDidChange),
            name: .hotkeyDidChange,
            object: nil
        )
    }
    
    // @note handle hotkey setting change
    @objc private func hotkeyDidChange() {
        unregister()
        register()
    }
    
    // @note register global hotkey based on settings
    func register() {
        let settings = AppSettings.shared
        let hotKeyID = EventHotKeyID(signature: OSType(0x53414349), id: 1) // "SACI"
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // @note retain self to prevent deallocation while handler is registered
        retainedSelf = Unmanaged.passRetained(self)
        let selfPtr = retainedSelf!.toOpaque()
        
        // @note install event handler
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        
        guard status == noErr else {
            retainedSelf?.release()
            retainedSelf = nil
            return
        }
        
        // @note register hotkey with modifier from settings (keycode 49 = space)
        var hotKeyRefTemp: EventHotKeyRef?
        RegisterEventHotKey(49, settings.hotkeyOption.modifierKey, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRefTemp)
        hotKeyRef = hotKeyRefTemp
    }
    
    // @note unregister hotkey
    func unregister() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        
        // @note release retained self after unregistering
        retainedSelf?.release()
        retainedSelf = nil
    }
    
    deinit {
        unregister()
        NotificationCenter.default.removeObserver(self)
    }
}

// @note global C function for hotkey event handler (required for Carbon API)
private func hotkeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData = userData else {
        return OSStatus(eventNotHandledErr)
    }
    
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    
    DispatchQueue.main.async {
        manager.onHotkeyPressed?()
    }
    
    return noErr
}
