//
//  AppSettings.swift
//  Saci
//

import SwiftUI
import Carbon

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

// @note emoji library hotkey options
enum EmojiHotkeyOption: String, CaseIterable {
    case none = "none"
    case optionE = "optionE"
    case commandE = "commandE"
    case controlE = "controlE"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .optionE: return "⌥ E"
        case .commandE: return "⌘ E"
        case .controlE: return "⌃ E"
        }
    }
    
    var modifierKey: UInt32? {
        switch self {
        case .none: return nil
        case .optionE: return UInt32(Carbon.optionKey)
        case .commandE: return UInt32(Carbon.cmdKey)
        case .controlE: return UInt32(Carbon.controlKey)
        }
    }
    
    var keyCode: UInt32? {
        switch self {
        case .none: return nil
        case .optionE, .commandE, .controlE: return 14
        }
    }
}

// @note clipboard history hotkey options
enum ClipboardHotkeyOption: String, CaseIterable {
    case none = "none"
    case commandShiftV = "commandShiftV"
    case optionShiftV = "optionShiftV"
    case controlShiftV = "controlShiftV"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .commandShiftV: return "⌘ ⇧ V"
        case .optionShiftV: return "⌥ ⇧ V"
        case .controlShiftV: return "⌃ ⇧ V"
        }
    }
    
    var modifierKey: UInt32? {
        switch self {
        case .none: return nil
        case .commandShiftV: return UInt32(Carbon.cmdKey | Carbon.shiftKey)
        case .optionShiftV: return UInt32(Carbon.optionKey | Carbon.shiftKey)
        case .controlShiftV: return UInt32(Carbon.controlKey | Carbon.shiftKey)
        }
    }
    
    var keyCode: UInt32? {
        switch self {
        case .none: return nil
        case .commandShiftV, .optionShiftV, .controlShiftV: return 9
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
    @AppStorage("appTheme") var appThemeRaw: String = AppTheme.system.rawValue
    @AppStorage("hotkeyOption") var hotkeyOptionRaw: String = HotkeyOption.optionSpace.rawValue
    @AppStorage("emojiHotkeyOption") var emojiHotkeyOptionRaw: String = EmojiHotkeyOption.none.rawValue
    @AppStorage("clipboardHotkeyOption") var clipboardHotkeyOptionRaw: String = ClipboardHotkeyOption.commandShiftV.rawValue
    @AppStorage("clipboardHistoryLimit") var clipboardHistoryLimit: Int = 1500 {
        didSet {
            if clipboardHistoryLimit < 100 { clipboardHistoryLimit = 100 }
            if clipboardHistoryLimit > 5000 { clipboardHistoryLimit = 5000 }
            ClipboardHistoryService.shared.enforceLimit()
        }
    }
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
    
    var emojiHotkeyOption: EmojiHotkeyOption {
        get { EmojiHotkeyOption(rawValue: emojiHotkeyOptionRaw) ?? .none }
        set {
            emojiHotkeyOptionRaw = newValue.rawValue
            NotificationCenter.default.post(name: .emojiHotkeyDidChange, object: nil)
        }
    }
    
    var clipboardHotkeyOption: ClipboardHotkeyOption {
        get { ClipboardHotkeyOption(rawValue: clipboardHotkeyOptionRaw) ?? .commandShiftV }
        set {
            clipboardHotkeyOptionRaw = newValue.rawValue
            NotificationCenter.default.post(name: .clipboardHotkeyDidChange, object: nil)
        }
    }
    
    var normalizedClipboardHistoryLimit: Int {
        min(5000, max(100, clipboardHistoryLimit))
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
            try LaunchAtLoginManager.shared.setEnabled(launchAtLogin)
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }
    
    // @note sync launch at login state on app start
    func syncLaunchAtLogin() {
        let enabled = LaunchAtLoginManager.shared.isEnabled
        if launchAtLogin != enabled {
            launchAtLogin = enabled
        }
    }
}

// @note manages launch-at-login via a LaunchAgent plist
// @note works for unsigned/un-notarized builds (no SMAppService / Developer ID required)
final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    private var label: String {
        Bundle.main.bundleIdentifier ?? "com.yoruakio.Saci"
    }
    
    // @note ~/Library/LaunchAgents/<bundle-id>.plist (real home, app is not sandboxed)
    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }
    
    // @note whether the login item plist currently exists
    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }
    
    // @note enable/disable the login item by writing/removing the LaunchAgent plist
    // @param enabled desired state
    func setEnabled(_ enabled: Bool) throws {
        let url = plistURL
        if enabled {
            guard let executablePath = Bundle.main.executableURL?.path else { return }
            let dir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let plist: [String: Any] = [
                "Label": label,
                "ProgramArguments": [executablePath],
                "RunAtLoad": true,
                "ProcessType": "Interactive"
            ]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
        } else if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

// @note notification names
extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
    static let emojiHotkeyDidChange = Notification.Name("emojiHotkeyDidChange")
    static let clipboardHotkeyDidChange = Notification.Name("clipboardHotkeyDidChange")
    static let themeDidChange = Notification.Name("themeDidChange")
    static let transparencyDidChange = Notification.Name("transparencyDidChange")
}
