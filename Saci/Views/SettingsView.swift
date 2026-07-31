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
        .frame(minHeight: 28)
    }
}

// @note visual effect background for settings window (legacy path retained for previews/tools)
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
    @State private var selectedClipboardHotkey: ClipboardHotkeyOption
    @State private var clipboardHistoryLimitText: String
    @State private var launchAtLogin: Bool
    @State private var enableTransparency: Bool
    var onClose: (() -> Void)?
    
    init(settings: AppSettings, selectedTab: Binding<SettingsTab>, onClose: (() -> Void)? = nil) {
        self.settings = settings
        self._selectedTab = selectedTab
        self.onClose = onClose
        self._selectedTheme = State(initialValue: settings.appTheme)
        self._selectedHotkey = State(initialValue: settings.hotkeyOption)
        self._selectedEmojiHotkey = State(initialValue: settings.emojiHotkeyOption)
        self._selectedClipboardHotkey = State(initialValue: settings.clipboardHotkeyOption)
        self._clipboardHistoryLimitText = State(initialValue: "\(settings.normalizedClipboardHistoryLimit)")
        self._launchAtLogin = State(initialValue: settings.launchAtLogin)
        self._enableTransparency = State(initialValue: settings.enableTransparency)
    }
    
    var body: some View {
        ZStack {
            SettingsWindowBackground(enableTransparency: settings.enableTransparency)
            
            VStack(spacing: 0) {
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
                
                settingsFooter
            }
        }
        .frame(width: settingsWindowWidth, height: settingsWindowHeight)
        .onAppear {
            settings.syncLaunchAtLogin()
            launchAtLogin = settings.launchAtLogin
        }
    }
    
    // @note slightly roomier window on Liquid Glass for toolbar chrome
    private var settingsWindowWidth: CGFloat {
        LauncherChrome.usesLiquidGlass ? 480 : 450
    }
    
    private var settingsWindowHeight: CGFloat {
        LauncherChrome.usesLiquidGlass ? 360 : 340
    }
    
    // @note get app version from bundle
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return "Saci v\(version)"
    }
    
    private var settingsFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Text(appVersion)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, LauncherChrome.usesLiquidGlass ? 10 : 8)
        }
    }
    
    // @note wrap tab rows in a soft card on Liquid Glass; plain stack elsewhere
    @ViewBuilder
    private func settingsSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if LauncherChrome.usesLiquidGlass {
            VStack(spacing: 14) {
                content()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            .padding(.top, 20)
        } else {
            VStack(spacing: 12) {
                content()
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
        }
    }
    
    // @note general settings tab content
    private var generalTab: some View {
        settingsSection {
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
            
            SettingsRow("Launch at Login:") {
                Toggle("", isOn: $launchAtLogin)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { newValue in
                        settings.launchAtLogin = newValue
                    }
            }
        }
    }
    
    // @note appearance settings tab content
    private var appearanceTab: some View {
        settingsSection {
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
            
            SettingsRow(LauncherChrome.usesLiquidGlass ? "Glass:" : "Transparency:") {
                HStack(spacing: 8) {
                    Toggle("", isOn: $enableTransparency)
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .onChange(of: enableTransparency) { newValue in
                            settings.enableTransparency = newValue
                        }
                    
                    Text(LauncherChrome.usesLiquidGlass
                         ? "Enable Liquid Glass on the launcher"
                         : "Enable window transparency")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            SettingsRow("") {
                Text(LauncherChrome.usesLiquidGlass
                     ? "Applies Liquid Glass to the launcher panel. Settings uses the system window style."
                     : "Transparency adds a blur effect behind windows. Disable for solid backgrounds.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // @note shortcut settings tab content
    private var shortcutTab: some View {
        settingsSection {
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
            
            SettingsRow("Clipboard History:") {
                Picker("", selection: $selectedClipboardHotkey) {
                    ForEach(ClipboardHotkeyOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .labelsHidden()
                .frame(width: 180)
                .onChange(of: selectedClipboardHotkey) { newValue in
                    settings.clipboardHotkeyOption = newValue
                }
            }
            
            SettingsRow("History Limit:") {
                TextField("1500", text: $clipboardHistoryLimitText)
                    .frame(width: 90)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        applyClipboardHistoryLimit()
                    }
                    .onChange(of: clipboardHistoryLimitText) { _ in
                        applyClipboardHistoryLimit()
                    }
                
                Text("100-5000")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // @note apply editable clipboard history limit within allowed range
    private func applyClipboardHistoryLimit() {
        let digits = clipboardHistoryLimitText.filter { $0.isNumber }
        if digits != clipboardHistoryLimitText {
            clipboardHistoryLimitText = digits
            return
        }
        guard let value = Int(digits) else { return }
        let clamped = min(5000, max(100, value))
        settings.clipboardHistoryLimit = clamped
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
            if #available(macOS 26, *) {
                // @note drop fullSizeContentView from earlier sessions so chrome isn't clipped oddly
                existingWindow.styleMask = [.titled, .closable]
            }
            refreshContentView()
            applyWindowChrome(to: existingWindow)
            existingWindow.setContentSize(NSSize(
                width: LauncherChrome.usesLiquidGlass ? 480 : 450,
                height: LauncherChrome.usesLiquidGlass ? 360 : 340
            ))
            return existingWindow
        }
        
        let contentWidth: CGFloat = LauncherChrome.usesLiquidGlass ? 480 : 450
        let contentHeight: CGFloat = LauncherChrome.usesLiquidGlass ? 360 : 340
        
        // @note avoid fullSizeContentView on Liquid Glass — lets system preference chrome render cleanly
        var style: NSWindow.StyleMask = [.titled, .closable]
        if !LauncherChrome.usesLiquidGlass {
            style.insert(.fullSizeContentView)
        }
        
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: contentWidth, height: contentHeight),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "Saci Settings"
        newWindow.isReleasedWhenClosed = false
        newWindow.toolbarStyle = .preference
        applyWindowChrome(to: newWindow)
        
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
        
        createContentView(for: newWindow)
        
        self.window = newWindow
        return newWindow
    }
    
    // @note system window materials on macOS 26+; legacy clear/blur elsewhere
    // @param window settings window to configure
    private func applyWindowChrome(to window: NSWindow) {
        if #available(macOS 26, *) {
            window.titlebarAppearsTransparent = false
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            window.toolbarStyle = .preference
        } else {
            window.titlebarAppearsTransparent = false
        }
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
        window.setContentSize(NSSize(
            width: LauncherChrome.usesLiquidGlass ? 480 : 450,
            height: LauncherChrome.usesLiquidGlass ? 360 : 340
        ))
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
    
    // @note apply transparency to window (launcher-oriented on macOS 26+)
    func applyTransparency() {
        guard let window = window else { return }
        
        // @note Tahoe settings use system window materials; don't clear the window
        if #available(macOS 26, *) {
            applyWindowChrome(to: window)
            return
        }
        
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
