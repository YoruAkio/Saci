//
//  AppSettings.swift
//  Saci
//

import SwiftUI
import Carbon
import ServiceManagement

// @note theme options enum
enum AppTheme: String, CaseIterable {
    case system = "system"
    case dark = "dark"
    case light = "light"
    
    var displayName: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }
}

// @note hotkey options enum
enum HotkeyOption: String, CaseIterable {
    case optionSpace = "optionSpace"
    case commandSpace = "commandSpace"
    case controlSpace = "controlSpace"
    
    var displayName: String {
        switch self {
        case .optionSpace: return "⌥ Space"
        case .commandSpace: return "⌘ Space"
        case .controlSpace: return "⌃ Space"
        }
    }
    
    // @note modifier symbol for keybind display
    var modifierSymbol: String {
        switch self {
        case .optionSpace: return "⌥"
        case .commandSpace: return "⌘"
        case .controlSpace: return "⌃"
        }
    }
    
    // @note NSEvent modifier flags for key detection
    var nsEventModifierFlag: NSEvent.ModifierFlags {
        switch self {
        case .optionSpace: return .option
        case .commandSpace: return .command
        case .controlSpace: return .control
        }
    }
    
    var modifierKey: UInt32 {
        switch self {
        case .optionSpace: return UInt32(Carbon.optionKey)
        case .commandSpace: return UInt32(Carbon.cmdKey)
        case .controlSpace: return UInt32(Carbon.controlKey)
        }
    }
}

// @note user preferences model using AppStorage
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet {
            updateLaunchAtLogin()
        }
    }
    @AppStorage("maxResults") var maxResults: Int = 8
    @AppStorage("appTheme") var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("hotkeyOption") var hotkeyOptionRaw: String = HotkeyOption.optionSpace.rawValue
    @AppStorage("enableTransparency") var enableTransparency: Bool = true {
        didSet {
            NotificationCenter.default.post(name: .transparencyDidChange, object: nil)
        }
    }
    
    var appTheme: AppTheme {
        get { AppTheme(rawValue: appThemeRaw) ?? .system }
        set { 
            appThemeRaw = newValue.rawValue
            applyTheme()
        }
    }
    
    var hotkeyOption: HotkeyOption {
        get { HotkeyOption(rawValue: hotkeyOptionRaw) ?? .optionSpace }
        set {
            hotkeyOptionRaw = newValue.rawValue
            NotificationCenter.default.post(name: .hotkeyDidChange, object: nil)
        }
    }
    
    // @note apply theme to app appearance
    func applyTheme() {
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
        
        // @note set app appearance based on theme
        switch appTheme {
        case .system:
            NSApp.appearance = nil
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }
    
    // @note update launch at login setting
    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
    
    // @note sync launch at login state on app start
    func syncLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

// @note notification names
extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
    static let themeDidChange = Notification.Name("themeDidChange")
    static let transparencyDidChange = Notification.Name("transparencyDidChange")
}
