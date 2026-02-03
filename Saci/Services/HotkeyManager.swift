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
    private var mainHotKeyRef: EventHotKeyRef?
    private var emojiHotKeyRef: EventHotKeyRef?
    private var retainedSelf: Unmanaged<HotkeyManager>?
    
    var onMainHotkeyPressed: (() -> Void)?
    var onEmojiHotkeyPressed: (() -> Void)?
    
    private init() {
        // @note observe hotkey changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyDidChange),
            name: .hotkeyDidChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeyDidChange),
            name: .emojiHotkeyDidChange,
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
        let mainHotKeyID = EventHotKeyID(signature: OSType(0x53414349), id: 1) // "SACI"
        let emojiHotKeyID = EventHotKeyID(signature: OSType(0x53414349), id: 2) // "SACI"
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        // @note retain self to prevent deallocation while handler is registered
        retainedSelf = Unmanaged.passRetained(self)
        let selfPtr = retainedSelf!.toOpaque()
        
        // @note install event handler
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
        
        if handlerStatus != noErr {
            retainedSelf?.release()
            retainedSelf = nil
            ErrorManager.shared.report(.hotkeyHandlerFailed(code: handlerStatus))
            return
        }
        
        // @note register main hotkey with modifier from settings (keycode 49 = space)
        var mainHotKeyRefTemp: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            49,
            settings.hotkeyOption.modifierKey,
            mainHotKeyID,
            GetApplicationEventTarget(),
            0,
            &mainHotKeyRefTemp
        )
        
        if registerStatus != noErr {
            // @note cleanup handler since hotkey failed
            if let handler = eventHandler {
                RemoveEventHandler(handler)
                eventHandler = nil
            }
            retainedSelf?.release()
            retainedSelf = nil
            ErrorManager.shared.report(.hotkeyRegistrationFailed(code: registerStatus))
            return
        }
        
        mainHotKeyRef = mainHotKeyRefTemp
        
        // @note register emoji hotkey if enabled
        if let modifier = settings.emojiHotkeyOption.modifierKey,
           let keyCode = settings.emojiHotkeyOption.keyCode {
            var emojiHotKeyRefTemp: EventHotKeyRef?
            let emojiStatus = RegisterEventHotKey(
                keyCode,
                modifier,
                emojiHotKeyID,
                GetApplicationEventTarget(),
                0,
                &emojiHotKeyRefTemp
            )
            
            if emojiStatus == noErr {
                emojiHotKeyRef = emojiHotKeyRefTemp
            } else {
                ErrorManager.shared.report(.hotkeyRegistrationFailed(code: emojiStatus))
            }
        }
    }
    
    // @note unregister hotkey
    func unregister() {
        if let hotKeyRef = mainHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.mainHotKeyRef = nil
        }
        
        if let hotKeyRef = emojiHotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.emojiHotKeyRef = nil
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
        var hotKeyID = EventHotKeyID()
        if let event = event {
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                if hotKeyID.id == 1 {
                    manager.onMainHotkeyPressed?()
                    return
                }
                if hotKeyID.id == 2 {
                    manager.onEmojiHotkeyPressed?()
                    return
                }
            }
        }
        
        manager.onMainHotkeyPressed?()
    }
    
    return noErr
}
