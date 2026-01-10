//
//  SaciApp.swift
//  Saci
//

import SwiftUI
import Combine

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

// @note non-activating panel for launcher (like Raycast/Alfred)
// @note this panel does not steal focus from the previous app
class SaciPanel: NSPanel {
    var onResignKey: (() -> Void)?
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    
    // @note called when panel loses key status (e.g., Cmd+Tab)
    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }
}

// @note app delegate to handle window configuration, hotkey and status bar
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    var hotkeyManager = HotkeyManager.shared
    var mainPanel: SaciPanel?
    var settingsWindow: NSWindow?
    var errorWindow: NSWindow?
    var statusItem: NSStatusItem?
    var localMouseEventMonitor: Any?
    var globalEventMonitor: Any?
    private var errorCancellable: AnyCancellable?
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        // @note check if another instance is already running
        if checkForExistingInstance() {
            NSApp.terminate(nil)
            return
        }
        
        // @note hide dock icon before anything else
        NSApp.setActivationPolicy(.accessory)
    }
    
    // @note check if another Saci instance is running and activate it
    // @return true if another instance exists
    private func checkForExistingInstance() -> Bool {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.yoruakio.Saci"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        
        // @note filter out current process
        let otherInstances = runningApps.filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        
        if let existingApp = otherInstances.first {
            // @note activate the existing instance
            existingApp.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            print("Saci is already running. Activating existing instance.")
            return true
        }
        
        return false
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // @note apply saved theme on launch
        AppSettings.shared.applyTheme()
        
        // @note sync launch at login state
        AppSettings.shared.syncLaunchAtLogin()
        
        // @note setup status bar icon
        setupStatusBar()
        
        // @note create main panel but don't show it
        createMainPanel()
        
        // @note setup event monitors
        setupEventMonitors()
        
        // @note setup error window observer
        setupErrorObserver()
        
        // @note register global hotkey
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.togglePanel()
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
    
    // @note handle theme change notification
    @objc private func themeDidChange() {
        // @note theme is already applied via AppSettings.applyTheme()
        // @note SwiftUI views update automatically via @Environment(\.colorScheme)
    }
    
    // @note handle dock icon setting change
    @objc private func dockIconSettingDidChange() {
        updateDockIconVisibility()
    }
    
    // @note handle transparency setting change
    @objc private func transparencyDidChange() {
        // @note SwiftUI views update automatically via @ObservedObject settings
        // @note no need to recreate window
        updateSettingsWindowTransparency()
    }
    
    // @note apply transparency setting to a window
    // @param window the window to update
    private func applyWindowTransparency(to window: NSWindow) {
        let settings = AppSettings.shared
        if settings.enableTransparency {
            window.isOpaque = false
            window.backgroundColor = .clear
        } else {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
        }
    }
    
    // @note update settings window transparency based on setting
    private func updateSettingsWindowTransparency() {
        guard let window = settingsWindow else { return }
        applyWindowTransparency(to: window)
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
        // @note local monitor for clicks on other windows (like settings)
        localMouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let mainPanel = self.mainPanel, mainPanel.isVisible else {
                return event
            }
            
            // @note check if click is outside main panel
            if event.window != mainPanel {
                self.hidePanel()
            }
            
            return event
        }
        
        // @note global monitor for clicks outside the app
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.mainPanel, panel.isVisible else {
                return
            }
            
            self.hidePanel()
        }
    }
    
    // @note setup observer for error window display using Combine
    private func setupErrorObserver() {
        errorCancellable = ErrorManager.shared.$showErrorWindow
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shouldShow in
                if shouldShow {
                    self?.showErrorWindow()
                }
            }
        
        // @note observe error window close notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closeErrorWindow),
            name: .errorWindowShouldClose,
            object: nil
        )
    }
    
    // @note close error window when dismiss is called
    @objc private func closeErrorWindow() {
        errorWindow?.close()
    }
    
    // @note show error window
    private func showErrorWindow() {
        let errorManager = ErrorManager.shared
        guard errorManager.currentError != nil else { return }
        
        if errorWindow == nil {
            errorWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 450, height: 280),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            errorWindow?.title = "Saci Error"
            errorWindow?.isReleasedWhenClosed = false
            errorWindow?.delegate = self
        }
        
        guard let window = errorWindow else { return }
        
        window.contentView = NSHostingView(rootView: ErrorWindowView())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
    
    // @note update menu item title based on panel visibility
    func menuWillOpen(_ menu: NSMenu) {
        if let toggleItem = menu.items.first {
            if mainPanel?.isVisible == true {
                toggleItem.title = "Hide Saci"
            } else {
                toggleItem.title = "Show Saci"
            }
        }
    }
    
    // @note create the main search panel (called once at startup)
    // @note uses NSPanel with nonactivatingPanel to avoid stealing focus
    private func createMainPanel() {
        let contentView = ContentView(
            onEscape: { [weak self] in
                self?.hidePanel()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
        
        mainPanel = SaciPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 100),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        guard let panel = mainPanel else { return }
        
        // @note close panel when it loses key status (Cmd+Tab, click elsewhere)
        panel.onResignKey = { [weak self] in
            self?.hidePanel()
        }
        
        panel.identifier = NSUserInterfaceItemIdentifier("main")
        panel.contentView = NSHostingView(rootView: contentView)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = false
        panel.isMovable = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.center()
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
        
        applyWindowTransparency(to: window)
        
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
    
    // @note handle window close events
    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        
        if closingWindow == settingsWindow {
            // @note hide dock icon when settings closes
            updateDockIconVisibility()
        } else if closingWindow == errorWindow {
            // @note reset error manager state when error window closes
            ErrorManager.shared.dismiss()
        }
    }
    
    // @note show the main panel without stealing focus from other apps
    private func showPanel() {
        guard let panel = mainPanel else { return }
        
        // @note notify that panel will show (for state reset)
        NotificationCenter.default.post(name: .saciWindowWillShow, object: nil)
        
        // @note position panel in upper third of screen using initial height (search bar only)
        // @note use fixed initial height to ensure consistent positioning
        let initialHeight: CGFloat = 100
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelWidth = panel.frame.width
            let x = screenFrame.midX - panelWidth / 2
            let y = screenFrame.minY + screenFrame.height * 0.73
            panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: initialHeight), display: false)
        } else {
            panel.center()
        }
        
        panel.makeKeyAndOrderFront(nil)
    }
    
    // @note hide the main panel (focus automatically returns to previous app)
    private func hidePanel() {
        mainPanel?.orderOut(nil)
        NotificationCenter.default.post(name: .saciWindowDidHide, object: nil)
    }
    
    // @note toggle from menu item
    @objc private func toggleWindowFromMenu() {
        togglePanel()
    }
    
    // @note toggle main panel visibility
    private func togglePanel() {
        guard let panel = mainPanel else { return }
        
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
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
        errorCancellable?.cancel()
        if let monitor = localMouseEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        NotificationCenter.default.removeObserver(self)
    }
}

// @note notification names for window events
extension Notification.Name {
    static let saciWindowDidHide = Notification.Name("saciWindowDidHide")
    static let saciWindowWillShow = Notification.Name("saciWindowWillShow")
    static let dockIconSettingDidChange = Notification.Name("dockIconSettingDidChange")
}
