//
//  SettingsView.swift
//  Saci
//

import SwiftUI

// @note settings tab enum
enum SettingsTab: String, CaseIterable {
    case general = "General"
    case appearance = "Appearance"
    
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintbrush.fill"
        }
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

// @note tab button for settings toolbar
struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(tab.rawValue)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .frame(width: 70, height: 50)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
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

// @note settings window with xcode-style tabbed layout
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedTab: SettingsTab = .general
    @State private var selectedTheme: AppTheme
    @State private var selectedHotkey: HotkeyOption
    @State private var launchAtLogin: Bool
    @State private var maxResults: Int
    @State private var showDockIcon: Bool
    @State private var enableTransparency: Bool
    var onClose: (() -> Void)?
    
    init(settings: AppSettings, onClose: (() -> Void)? = nil) {
        self.settings = settings
        self.onClose = onClose
        self._selectedTheme = State(initialValue: settings.appTheme)
        self._selectedHotkey = State(initialValue: settings.hotkeyOption)
        self._launchAtLogin = State(initialValue: settings.launchAtLogin)
        self._maxResults = State(initialValue: settings.maxResults)
        self._showDockIcon = State(initialValue: settings.showDockIcon)
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
                // @note tab toolbar
                HStack(spacing: 4) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        SettingsTabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: { selectedTab = tab }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                Divider()
                
                // @note tab content
                Group {
                    switch selectedTab {
                    case .general:
                        generalTab
                    case .appearance:
                        appearanceTab
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                
                // @note footer
                Divider()
                
                Text("Saci v0.1.0-alpha")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .frame(width: 500, height: 340)
        .onAppear {
            settings.syncLaunchAtLogin()
            launchAtLogin = settings.launchAtLogin
        }
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
            
            // @note show dock icon toggle
            SettingsRow("Show in Dock:") {
                HStack(spacing: 8) {
                    Toggle("", isOn: $showDockIcon)
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                        .onChange(of: showDockIcon) { newValue in
                            settings.showDockIcon = newValue
                            NotificationCenter.default.post(name: .dockIconSettingDidChange, object: nil)
                        }
                    
                    Text("When settings is open")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
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
}
