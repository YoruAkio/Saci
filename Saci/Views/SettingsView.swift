//
//  SettingsView.swift
//  Saci
//

import SwiftUI

// @note settings tab enum
enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    case shortcut = "Shortcut"
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .appearance: return "paintbrush"
        case .shortcut: return "keyboard"
        }
    }
    
    var toolbarIdentifier: NSToolbarItem.Identifier {
        return NSToolbarItem.Identifier(rawValue: self.rawValue)
    }
}

// @note xcode-style settings row with right-aligned label
struct SettingsRow<Content: View>: View {
    let label: String
    let content: Content
    
    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .frame(width: 140, alignment: .trailing)
            
            content
            
            Spacer()
        }
        .frame(height: 24)
    }
}

// @note visual effect background for settings window
struct SettingsVisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// @note settings window content view (without toolbar, handled by NSToolbar)
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Binding var selectedTab: SettingsTab
    @State private var selectedTheme: AppTheme
    @State private var selectedHotkey: HotkeyOption
    @State private var selectedEmojiHotkey: EmojiHotkeyOption
    @State private var launchAtLogin: Bool
    @State private var maxResults: Int
    @State private var enableTransparency: Bool
    var onClose: (() -> Void)?
    
    init(settings: AppSettings, selectedTab: Binding<SettingsTab>, onClose: (() -> Void)? = nil) {
        self.settings = settings
        self._selectedTab = selectedTab
        self.onClose = onClose
        self._selectedTheme = State(initialValue: settings.appTheme)
        self._selectedHotkey = State(initialValue: settings.hotkeyOption)
        self._selectedEmojiHotkey = State(initialValue: settings.emojiHotkeyOption)
        self._launchAtLogin = State(initialValue: settings.launchAtLogin)
        self._maxResults = State(initialValue: settings.maxResults)
        self._enableTransparency = State(initialValue: settings.enableTransparency)
    }
    
    var body: some View {
        ZStack {
            // @note transparent background
            if settings.enableTransparency {
                SettingsVisualEffectBackground(
                    material: .sidebar,
                    blendingMode: .behindWindow
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // @note tab content
                Group {
                    switch selectedTab {
                    case .general:
                        generalTab
                    case .appearance:
                        appearanceTab
                    case .shortcut:
                        shortcutTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                Spacer()
                
                // @note footer
                Divider()
                
                Text(appVersion)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .frame(width: 450, height: 260)
        .onAppear {
            settings.syncLaunchAtLogin()
            launchAtLogin = settings.launchAtLogin
        }
    }
    
    // @note get app version from bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return "Saci v\(version)"
    }
    
    // @note general settings tab content
    private var generalTab: some View {
        VStack(spacing: 12) {
            // @note hotkey picker
            SettingsRow("Hotkey:") {
                Picker("", selection: $selectedHotkey) {
                    ForEach(HotkeyOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
                .onChange(of: selectedHotkey) { newValue in
                    settings.hotkeyOption = newValue
                }
            }
            
            // @note max results picker
            SettingsRow("Max Results:") {
                Picker("", selection: $maxResults) {
                    Text("5").tag(5)
                    Text("8").tag(8)
                    Text("10").tag(10)
                    Text("15").tag(15)
                }
                .labelsHidden()
                .frame(width: 160)
                .onChange(of: maxResults) { newValue in
                    settings.maxResults = newValue
                }
            }
            
            // @note launch at login toggle
            SettingsRow("Launch at Login:") {
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { newValue in
                        settings.launchAtLogin = newValue
                    }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
    }
    
    // @note appearance settings tab content
    private var appearanceTab: some View {
        VStack(spacing: 12) {
            // @note theme picker
            SettingsRow("Appearance:") {
                Picker("", selection: $selectedTheme) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .labelsHidden()
                .frame(width: 160)
                .onChange(of: selectedTheme) { newValue in
                    settings.appTheme = newValue
                }
            }
            
            // @note transparency toggle
            SettingsRow("Transparency:") {
                HStack(spacing: 8) {
                    Toggle("", isOn: $enableTransparency)
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .onChange(of: enableTransparency) { newValue in
                            settings.enableTransparency = newValue
                        }
                    
                    Text("Enable window transparency")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            // @note description
            SettingsRow("") {
                Text("Transparency adds a blur effect behind windows. Disable for solid backgrounds.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
    }
    
    // @note shortcut settings tab content
    private var shortcutTab: some View {
        VStack(spacing: 12) {
            // @note emoji library hotkey picker
            SettingsRow("Emoji Library:") {
                Picker("", selection: $selectedEmojiHotkey) {
                    ForEach(EmojiHotkeyOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
                .onChange(of: selectedEmojiHotkey) { newValue in
                    settings.emojiHotkeyOption = newValue
                }
            }
            
            SettingsRow("") {
                Text("Set a shortcut to open the Emoji Library directly.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
    }
}

// @note NSToolbar delegate for settings window
class SettingsToolbarDelegate: NSObject, NSToolbarDelegate {
    var selectedTab: SettingsTab = .general
    var onTabChange: ((SettingsTab) -> Void)?
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let tab = SettingsTab.allCases.first(where: { $0.toolbarIdentifier == itemIdentifier }) else {
            return nil
        }
        
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = tab.rawValue
        item.image = NSImage(systemSymbolName: tab.icon, accessibilityDescription: tab.rawValue)
        item.target = self
        item.action = #selector(toolbarItemClicked(_:))
        
        return item
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [
            .flexibleSpace,
            SettingsTab.general.toolbarIdentifier,
            SettingsTab.appearance.toolbarIdentifier,
            SettingsTab.shortcut.toolbarIdentifier,
            .flexibleSpace
        ]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return toolbarDefaultItemIdentifiers(toolbar)
    }
    
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return SettingsTab.allCases.map { $0.toolbarIdentifier }
    }
    
    @objc private func toolbarItemClicked(_ sender: NSToolbarItem) {
        guard let tab = SettingsTab.allCases.first(where: { $0.toolbarIdentifier == sender.itemIdentifier }) else {
            return
        }
        selectedTab = tab
        onTabChange?(tab)
    }
}

// @note settings window controller to manage NSToolbar
class SettingsWindowController: NSObject, NSWindowDelegate {
    var window: NSWindow?
    var toolbarDelegate: SettingsToolbarDelegate?
    var hostingView: NSHostingView<SettingsView>?
    var selectedTab: SettingsTab = .general
    
    // @note create and configure the settings window with NSToolbar
    func createWindow() -> NSWindow {
        // @note reuse existing window if available
        if let existingWindow = window {
            // @note refresh content view to ensure it displays properly
            refreshContentView()
            return existingWindow
        }
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 260),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Saci Settings"
        newWindow.isReleasedWhenClosed = false
        newWindow.titlebarAppearsTransparent = false
        newWindow.toolbarStyle = .preference
        
        // @note create toolbar
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.displayMode = .iconAndLabel
        
        toolbarDelegate = SettingsToolbarDelegate()
        toolbarDelegate?.selectedTab = selectedTab
        toolbarDelegate?.onTabChange = { [weak self] tab in
            self?.selectedTab = tab
            self?.updateContent()
        }
        
        toolbar.delegate = toolbarDelegate
        toolbar.selectedItemIdentifier = selectedTab.toolbarIdentifier
        newWindow.toolbar = toolbar
        
        // @note create content view
        createContentView(for: newWindow)
        
        self.window = newWindow
        return newWindow
    }
    
    // @note update content view when tab changes
    private func updateContent() {
        guard let window = window else { return }
        window.toolbar?.selectedItemIdentifier = selectedTab.toolbarIdentifier
        refreshContentView()
    }
    
    // @note create hosting view for the first time
    private func createContentView(for window: NSWindow) {
        let settings = AppSettings.shared
        let binding = Binding<SettingsTab>(
            get: { self.selectedTab },
            set: { newValue in
                self.selectedTab = newValue
                self.toolbarDelegate?.selectedTab = newValue
                self.window?.toolbar?.selectedItemIdentifier = newValue.toolbarIdentifier
            }
        )
        
        let settingsView = SettingsView(settings: settings, selectedTab: binding)
        hostingView = NSHostingView(rootView: settingsView)
        window.contentView = hostingView
    }
    
    // @note refresh hosting view with new root view
    private func refreshContentView() {
        guard let window = window else { return }
        
        let settings = AppSettings.shared
        let binding = Binding<SettingsTab>(
            get: { self.selectedTab },
            set: { newValue in
                self.selectedTab = newValue
                self.toolbarDelegate?.selectedTab = newValue
                self.window?.toolbar?.selectedItemIdentifier = newValue.toolbarIdentifier
            }
        )
        
        let settingsView = SettingsView(settings: settings, selectedTab: binding)
        
        if let existingView = hostingView {
            existingView.rootView = settingsView
        } else {
            hostingView = NSHostingView(rootView: settingsView)
            window.contentView = hostingView
        }
    }
    
    // @note apply transparency to window
    func applyTransparency() {
        guard let window = window else { return }
        let settings = AppSettings.shared
        if settings.enableTransparency {
            window.isOpaque = false
            window.backgroundColor = .clear
        } else {
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
        }
    }
}
