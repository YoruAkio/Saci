//
//  SaciApp.swift
//  Saci
//

import SwiftUI

@main
struct SaciApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // @note use Settings scene to avoid automatic window management
        Settings {
            EmptyView()
        }
    }
}

// @note custom window that can become key (required for borderless windows to accept keyboard input)
class SaciWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// @note app delegate to handle window configuration, hotkey and status bar
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    var hotkeyManager = HotkeyManager.shared
    var mainWindow: SaciWindow?
    var settingsWindow: NSWindow?
    var statusItem: NSStatusItem?
    var localKeyEventMonitor: Any?
    var localMouseEventMonitor: Any?
    var globalEventMonitor: Any?
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // @note hide dock icon before anything else
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // @note apply saved theme on launch
        applyTheme()
        
        // @note sync launch at login state
        AppSettings.shared.syncLaunchAtLogin()
        
        // @note setup status bar icon
        setupStatusBar()
        
        // @note create main window but don't show it
        createMainWindow()
        
        // @note setup event monitors
        setupEventMonitors()
        
        // @note register global hotkey
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.toggleWindow()
        }
        hotkeyManager.register()
        
        // @note observe theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
        
        // @note observe dock icon setting changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dockIconSettingDidChange),
            name: .dockIconSettingDidChange,
            object: nil
        )
        
        // @note observe transparency setting changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(transparencyDidChange),
            name: .transparencyDidChange,
            object: nil
        )
    }
    
    // @note apply theme from settings
    private func applyTheme() {
        let settings = AppSettings.shared
        switch settings.appTheme {
        case .system:
            NSApp.appearance = nil
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        }
    }
    
    // @note handle theme change notification
    @objc private func themeDidChange() {
        applyTheme()
        
        // @note recreate main window with new theme
        let wasVisible = mainWindow?.isVisible ?? false
        createMainWindow()
        if wasVisible {
            showWindow()
        }
        
        // @note settings window updates automatically via NSApp.appearance
    }
    
    // @note handle dock icon setting change
    @objc private func dockIconSettingDidChange() {
        updateDockIconVisibility()
    }
    
    // @note handle transparency setting change
    @objc private func transparencyDidChange() {
        // @note recreate main window with new transparency
        let wasVisible = mainWindow?.isVisible ?? false
        createMainWindow()
        if wasVisible {
            showWindow()
        }
        
        // @note update settings window transparency
        updateSettingsWindowTransparency()
    }
    
    // @note update settings window transparency based on setting
    private func updateSettingsWindowTransparency() {
        guard let window = settingsWindow else { return }
        let settings = AppSettings.shared
        
        if settings.enableTransparency {
            window.isOpaque = false
            window.backgroundColor = .clear
        } else {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
        }
    }
    
    // @note update dock icon based on settings and window state
    private func updateDockIconVisibility() {
        let settings = AppSettings.shared
        let settingsOpen = settingsWindow?.isVisible ?? false
        
        if settings.showDockIcon && settingsOpen {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    // @note setup local and global event monitors
    private func setupEventMonitors() {
        // @note local monitor for ESC key
        localKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let window = self.mainWindow, window.isVisible else {
                return event
            }
            
            if event.keyCode == 53 {
                self.hideWindow()
                return nil
            }
            
            return event
        }
        
        // @note local monitor for clicks on other windows (like settings)
        localMouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let mainWindow = self.mainWindow, mainWindow.isVisible else {
                return event
            }
            
            // @note check if click is outside main window
            if event.window != mainWindow {
                self.hideWindow()
            }
            
            return event
        }
        
        // @note global monitor for clicks outside the app
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.mainWindow, window.isVisible else {
                return
            }
            
            self.hideWindow()
        }
    }
    
    // @note setup status bar item with menu
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Saci")
        }
        
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Show Saci", action: #selector(toggleWindowFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Saci", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // @note update menu item title based on window visibility
    func menuWillOpen(_ menu: NSMenu) {
        if let toggleItem = menu.items.first {
            if mainWindow?.isVisible == true {
                toggleItem.title = "Hide Saci"
            } else {
                toggleItem.title = "Show Saci"
            }
        }
    }
    
    // @note create the main search window (hidden by default)
    private func createMainWindow() {
        let contentView = ContentView(onEscape: { [weak self] in
            self?.hideWindow()
        })
        
        if mainWindow == nil {
            mainWindow = SaciWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 100),
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        }
        
        guard let window = mainWindow else { return }
        
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.contentView = NSHostingView(rootView: contentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
    }
    
    // @note open settings window
    @objc private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settings = AppSettings.shared
        let settingsView = SettingsView(settings: settings, onClose: { [weak self] in
            self?.closeSettings()
        })
        
        if settingsWindow == nil {
            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 340),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Saci Settings"
            settingsWindow?.isReleasedWhenClosed = false
            settingsWindow?.delegate = self
            settingsWindow?.titlebarAppearsTransparent = true
        }
        
        guard let window = settingsWindow else { return }
        
        // @note apply transparency based on setting
        if settings.enableTransparency {
            window.isOpaque = false
            window.backgroundColor = .clear
        } else {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
        }
        
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // @note show dock icon when settings opens
        updateDockIconVisibility()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // @note close settings window
    private func closeSettings() {
        settingsWindow?.close()
    }
    
    // @note handle settings window close
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow == settingsWindow {
            // @note hide dock icon when settings closes
            updateDockIconVisibility()
        }
    }
    
    // @note show the main window and focus text field
    private func showWindow() {
        guard let window = mainWindow else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    // @note hide the main window
    private func hideWindow() {
        mainWindow?.orderOut(nil)
        NotificationCenter.default.post(name: .saciWindowDidHide, object: nil)
    }
    
    // @note toggle from menu item
    @objc private func toggleWindowFromMenu() {
        toggleWindow()
    }
    
    // @note toggle main window visibility
    private func toggleWindow() {
        guard let window = mainWindow else { return }
        
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
    
    // @note quit the application
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
    
    // @note prevent app from terminating when last window closes
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
        if let monitor = localKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMouseEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// @note notification name for window hide event
extension Notification.Name {
    static let saciWindowDidHide = Notification.Name("saciWindowDidHide")
    static let dockIconSettingDidChange = Notification.Name("dockIconSettingDidChange")
}
