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
    var settingsWindowController: SettingsWindowController?
    var errorWindow: NSWindow?
    var statusItem: NSStatusItem?
    var localMouseEventMonitor: Any?
    var globalEventMonitor: Any?
    private var errorCancellable: AnyCancellable?
    
    // @note flag to prevent panel closing when transitioning to child windows (settings, etc.)
    private var isTransitioningToChildWindow = false
    
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
        
        // @note start performance monitoring in debug builds only
        #if DEBUG
        PerformanceMonitor.shared.startMonitoring(interval: 3.0)
        #endif
        
        // @note observe theme changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .themeDidChange,
            object: nil
        )
        
        // @note observe transparency setting changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(transparencyDidChange),
            name: .transparencyDidChange,
            object: nil
        )
        
        // @note observe when another app becomes active (for Cmd+Tab detection)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(anotherAppDidActivate(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    // @note handle theme change notification
    @objc private func themeDidChange() {
        // @note theme is already applied via AppSettings.applyTheme()
        // @note SwiftUI views update automatically via @Environment(\.colorScheme)
    }
    
    // @note handle transparency setting change
    @objc private func transparencyDidChange() {
        // @note SwiftUI views update automatically via @ObservedObject settings
        // @note no need to recreate window
        updateSettingsWindowTransparency()
    }
    
    // @note handle when another app becomes active (Cmd+Tab, clicking other app, etc.)
    // @param notification contains info about the activated app
    @objc private func anotherAppDidActivate(_ notification: Notification) {
        guard let panel = mainPanel, panel.isVisible else { return }
        
        // @note check if the activated app is ours - if so, don't hide
        if let userInfo = notification.userInfo,
           let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
           app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        
        // @note another app became active, hide the panel
        hidePanel()
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
        settingsWindowController?.applyTransparency()
    }
    
    // @note update dock icon based on settings window visibility
    private func updateDockIconVisibility() {
        let settingsVisible = settingsWindowController?.window?.isVisible ?? false
        
        if settingsVisible {
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
            
            // @note don't hide if transitioning to child window
            if self.isTransitioningToChildWindow {
                return event
            }
            
            // @note check if click is on a popover (child of main panel)
            let isPopover = event.window?.className.contains("Popover") ?? false
            let isChildOfPanel = event.window?.parent == mainPanel
            
            // @note check if click is outside main panel and not on popover
            if event.window != mainPanel && !isPopover && !isChildOfPanel {
                self.hidePanel()
            }
            
            return event
        }
        
        // @note global monitor for clicks outside the app
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.mainPanel, panel.isVisible else {
                return
            }
            
            // @note don't hide if transitioning to child window
            if self.isTransitioningToChildWindow {
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
        
        // @note get version from bundle
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Toggle Saci", action: #selector(toggleWindowFromMenu), keyEquivalent: ""))
        
        // @note version item (disabled, just for display)
        let versionItem = NSMenuItem(title: "Saci \(version) [\(build)]", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Saci", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    // @note update menu item title based on panel visibility
    func menuWillOpen(_ menu: NSMenu) {
        // @note toggle item is at index 0
        if let toggleItem = menu.items.first {
            toggleItem.title = mainPanel?.isVisible == true ? "Hide Saci" : "Show Saci"
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
                // @note open settings and hide panel when opened from footer
                self?.openSettingsWindow(andHidePanel: true)
            }
        )
        
        mainPanel = SaciPanel(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 100),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        guard let panel = mainPanel else { return }
        
        // @note conditionally hide panel when it loses key status (ignore popovers and our windows)
        panel.onResignKey = { [weak self] in
            guard let self = self else { return }
            
            // @note don't hide if transitioning to a child window (settings, etc.)
            if self.isTransitioningToChildWindow { return }
            
            // @note delay to allow new key window to be set reliably
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // @note double-check flag in case it was set during delay
                if self.isTransitioningToChildWindow { return }
                
                let newKeyWindow = NSApp.keyWindow
                
                // @note check if new window is a popover by class name
                let isPopover = newKeyWindow?.className.contains("Popover") ?? false
                
                // @note don't hide if focus moved to our windows or popover
                let isOurWindow = newKeyWindow == self.mainPanel ||
                                  newKeyWindow == self.settingsWindowController?.window ||
                                  newKeyWindow == self.errorWindow ||
                                  newKeyWindow?.parent == self.mainPanel ||
                                  isPopover
                
                if !isOurWindow {
                    self.hidePanel()
                }
            }
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
    // @param hidePanel if true, hides the main panel after opening settings
    @objc private func openSettings() {
        openSettingsWindow(andHidePanel: false)
    }
    
    // @note open settings window with option to hide panel
    // @param andHidePanel if true, hides the main panel after opening settings
    private func openSettingsWindow(andHidePanel shouldHidePanel: Bool) {
        // @note set flag to prevent panel from closing during transition
        isTransitioningToChildWindow = true
        
        // @note reset flag after delay to allow all window transitions to complete
        // @note this must be longer than the resignKey delay (0.05s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isTransitioningToChildWindow = false
        }
        
        if let window = settingsWindowController?.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            if shouldHidePanel { hidePanel() }
            return
        }
        
        // @note create settings window controller if needed
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        
        guard let controller = settingsWindowController else { return }
        
        let window = controller.createWindow()
        window.delegate = self
        controller.applyTransparency()
        
        window.center()
        window.makeKeyAndOrderFront(nil)
        
        // @note show dock icon when settings opens
        updateDockIconVisibility()
        NSApp.activate(ignoringOtherApps: true)
        
        // @note hide panel after settings is opened (when requested)
        if shouldHidePanel { hidePanel() }
    }
    
    // @note close settings window
    private func closeSettings() {
        settingsWindowController?.window?.close()
    }
    
    // @note handle window close events
    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow else { return }
        
        if closingWindow == settingsWindowController?.window {
            // @note hide dock icon directly since window is still visible at this point
            NSApp.setActivationPolicy(.accessory)
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
        
        // @note use fixed initial height to ensure consistent positioning
        let initialHeight: CGFloat = 100
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelWidth = panel.frame.width
            
            // @note calculate center position of screen
            let centerX = screenFrame.midX - panelWidth / 2
            let screenCenterY = screenFrame.midY
            
            // @note move down from center by 15% of screen height
            let windowCenterY = screenCenterY - (screenFrame.height * 0.15)
            
            panel.setFrame(NSRect(x: centerX, y: windowCenterY, width: panelWidth, height: initialHeight), display: false)
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
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        
        // @note stop performance monitoring in debug builds
        #if DEBUG
        PerformanceMonitor.shared.stopMonitoring()
        #endif
    }
}

// @note notification names for window events
extension Notification.Name {
    static let saciWindowDidHide = Notification.Name("saciWindowDidHide")
    static let saciWindowWillShow = Notification.Name("saciWindowWillShow")
}
