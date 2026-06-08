//
//  ContentView.swift
//  Saci
//

import SwiftUI

// @note visual effect view for transparency/blur effect
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var cornerRadius: CGFloat
    var opacity: CGFloat = 1.0
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        view.alphaValue = opacity
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.alphaValue = opacity
    }
}

// @note footer menu button (toggles the floating menu box owned by ContentView)
struct FooterMenuButton: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        Button(action: { isPresented.toggle() }) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
    }
}

// @note floating footer menu box (version + settings), positioned by its parent
struct FooterMenuBox: View {
    var onSettings: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private var menuBackgroundColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.17, alpha: 1))
            : Color(nsColor: NSColor(white: 0.99, alpha: 1))
    }
    
    private var menuBorderColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.82, alpha: 1))
    }
    
    private var menuRowHoverColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.92, alpha: 1))
    }
    
    private var dividerColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.82, alpha: 1))
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return "Saci v\(version)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(appVersion)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
            
            HoverButton(
                hoverColor: menuRowHoverColor,
                action: onSettings
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .frame(width: 18)
                    
                    Text("Settings")
                        .font(.system(size: 13))
                    
                    Spacer()
                    
                    Text("⌘ ,")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        }
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(menuBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(menuBorderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
    }
}

// @note simple hover-highlight button row used by the footer menu
private struct HoverButton<Label: View>: View {
    let hoverColor: Color
    let action: () -> Void
    @ViewBuilder let label: () -> Label
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            label()
                .contentShape(Rectangle())
                .background(isHovered ? hoverColor : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// @note a single clipboard type filter row with hover + selected states
private struct ClipboardTypeRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.22) }
        if isHovered { return Color.secondary.opacity(0.15) }
        return Color.clear
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(rowBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// @note search window footer bar
struct SearchFooterView: View {
    @Binding var showMenu: Bool
    var enableTransparency: Bool
    var actionText: String = "Open Application"
    @Environment(\.colorScheme) var colorScheme
    
    // @note semi-transparent overlay color above the blur (95% opacity)
    private var footerOverlayColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.08, alpha: 0.95))
            : Color(nsColor: NSColor(white: 0.85, alpha: 0.95))
    }
    
    // @note solid background when transparency disabled
    private var footerSolidColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.1, alpha: 1))
            : Color(nsColor: NSColor(white: 0.88, alpha: 1))
    }
    
    var body: some View {
        HStack(spacing: 8) {
            FooterMenuButton(isPresented: $showMenu)
            
            Spacer()
            
            // @note action hint
            HStack(spacing: 6) {
                Text(actionText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text("↵")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 22, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(enableTransparency ? footerOverlayColor : footerSolidColor)
    }
}

// @note launcher modes for search and emoji library
enum LauncherMode {
    case search
    case emoji
    case clipboard
}

// @note emoji section data for grouped display
struct EmojiSectionData: Identifiable {
    let id: String
    let title: String
    let entries: [EmojiEntry]
    let offset: Int
}

// @note main search window UI
struct ContentView: View {
    @ObservedObject private var searchService = AppSearchService.shared
    @ObservedObject private var emojiService = EmojiLibraryService.shared
    @ObservedObject private var clipboardService = ClipboardHistoryService.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var calculatorResult: CalculatorResult?
    // @note clipboard actions popover visibility
    @State private var showClipboardActions = false
    // @note selected action index in the clipboard actions box
    @State private var clipboardActionIndex = 0
    // @note footer menu (version + settings) visibility
    @State private var showFooterMenu = false
    // @note clipboard type filter dropdown visibility
    @State private var showClipboardTypeMenu = false
    @State private var mode: LauncherMode = .search
    @State private var emojiSections: [EmojiSectionData] = []
    @State private var emojiDisplayEntries: [EmojiEntry] = []
    @State private var emojiCategories: [EmojiCategory] = [.all, .frequent]
    @State private var emojiSelectedCategoryId: String = EmojiCategory.all.id
    @State private var showEmojiCategoryMenu = false
    @State private var copiedEmojiToken: String?
    @State private var showCopiedFeedback = false
    @Environment(\.colorScheme) var colorScheme
    
    // @note debounce work item for calculator
    @State private var calculatorWorkItem: DispatchWorkItem?
    
    var onEscape: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    
    init(onEscape: (() -> Void)? = nil, onOpenSettings: (() -> Void)? = nil) {
        self.onEscape = onEscape
        self.onOpenSettings = onOpenSettings
    }
    
    // @note check if calculator result is selected (index -1 means calculator)
    private var isCalculatorSelected: Bool {
        mode == .search && calculatorResult != nil && selectedIndex == -1
    }
    
    // @note check if footer should be visible
    private var showFooter: Bool {
        if mode == .emoji {
            return true
        }
        if mode == .clipboard {
            // @note clipboard view renders its own footer
            return false
        }
        return !currentResults.isEmpty || calculatorResult != nil
    }
    
    // @note footer action text based on selection
    private var footerActionText: String {
        if mode == .emoji {
            return "Click to Copy"
        }
        if mode == .clipboard {
            return "Copy Item"
        }
        if isCalculatorSelected {
            return "Copy Result"
        }
        if let selected = selectedResult {
            if selected.kind == .command {
                if selected.path == SearchResult.clipboardHistoryCommandShared.path {
                    return "Open Clipboard History"
                }
                return "Open Emoji Library"
            }
            // @note app selected: show its name
            return "Open \(selected.name)"
        }
        return "Open Application"
    }
    
    // @note background color based on theme (used when transparency disabled)
    private var solidBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(nsColor: NSColor(white: 0.12, alpha: 1))
            : Color(nsColor: NSColor(white: 0.95, alpha: 1))
    }

    // @note fixed height for emoji mode
    private var emojiPanelHeight: CGFloat {
        460
    }
    
    private var clipboardPanelHeight: CGFloat {
        460
    }

    // @note emoji category dropdown sizing
    private var emojiDropdownWidth: CGFloat {
        170
    }
    
    private var emojiDropdownHeight: CGFloat {
        26
    }
    
    // @note background overlay color for transparency mode (50% opacity)
    private var backgroundOverlayColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.12, alpha: 0.50))
            : Color(nsColor: NSColor(white: 0.95, alpha: 0.50))
    }
    
    // @note divider color based on theme
    private var dividerColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.8, alpha: 1))
    }
    
    // @note dropdown background color
    private var dropdownBackgroundColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.16, alpha: 1))
            : Color(nsColor: NSColor(white: 0.95, alpha: 1))
    }
    
    // @note dropdown border color
    private var dropdownBorderColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.28, alpha: 1))
            : Color(nsColor: NSColor(white: 0.8, alpha: 1))
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // @note search bar
            SearchTextField(
                text: $searchText,
                placeholder: searchPlaceholder,
                rightPadding: mode == .emoji ? (emojiDropdownWidth + 30) : 20,
                colorScheme: colorScheme,
                enableTransparency: settings.enableTransparency,
                onEscape: {
                    handleEscape()
                },
                onLeftArrow: {
                    handleLeftArrow()
                },
                onRightArrow: {
                    handleRightArrow()
                },
                onArrowUp: {
                    handleArrowUp()
                },
                onArrowDown: {
                    handleArrowDown()
                },
                onSubmit: {
                    handleSubmit()
                },
                onCommandComma: {
                    openSettings()
                },
                onCommandNumber: { index in
                    launchAppAtIndex(index)
                },
                onCommandK: {
                    guard mode == .clipboard else { return false }
                    showClipboardActions.toggle()
                    if showClipboardActions { clipboardActionIndex = 0 }
                    return true
                },
                onCommandC: {
                    guard mode == .clipboard,
                          selectedIndex >= 0, selectedIndex < clipboardService.results.count else { return false }
                    executeClipboardAction(.copy)
                    return true
                },
                onCommandP: {
                    guard mode == .clipboard,
                          selectedIndex >= 0, selectedIndex < clipboardService.results.count else { return false }
                    executeClipboardAction(.pin)
                    return true
                },
                onControlX: {
                    guard mode == .clipboard,
                          selectedIndex >= 0, selectedIndex < clipboardService.results.count else { return false }
                    executeClipboardAction(.delete)
                    return true
                },
                onCommandShiftDelete: {
                    guard mode == .clipboard else { return false }
                    executeClipboardAction(.clearAll)
                    return true
                }
            )
                
                // @note divider
                if mode == .emoji {
                    if !emojiDisplayEntries.isEmpty {
                        Rectangle()
                            .fill(dividerColor)
                            .frame(height: 1)
                    }
                } else if mode == .clipboard {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                } else if !currentResults.isEmpty || calculatorResult != nil {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }
                
                // @note calculator result (shown above app results)
                if mode == .search, let calcResult = calculatorResult {
                    CalculatorResultContainer(
                        result: calcResult,
                        isSelected: isCalculatorSelected,
                        showCopied: showCopiedFeedback,
                        onCopy: copyCalculatorResult
                    )
                    
                    // @note divider between calculator and app results
                    if !currentResults.isEmpty {
                        Rectangle()
                            .fill(dividerColor)
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                }
                
                if mode == .emoji {
                    if emojiSections.isEmpty {
                        Text("No emojis found")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 24)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(emojiSections) { section in
                                    if !section.title.isEmpty {
                                        EmojiSectionHeaderView(
                                            title: section.title,
                                            count: section.entries.count
                                        )
                                    }
                                    
                                    EmojiGridView(
                                        emojis: section.entries,
                                        copiedEmojiToken: copiedEmojiToken,
                                        tokenPrefix: section.id,
                                        onSelect: { entry in
                                            copyEmoji(entry, token: "\(section.id)|\(entry.id)")
                                        },
                                        columns: emojiGridColumns
                                    )
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .frame(maxHeight: .infinity)
                    }
                } else if mode == .clipboard {
                    ClipboardHistoryView(
                        service: clipboardService,
                        entries: clipboardService.results,
                        selectedIndex: $selectedIndex,
                        showActions: $showClipboardActions,
                        actionIndex: $clipboardActionIndex,
                        onRunAction: { action in executeClipboardAction(action) }
                    )
                    .frame(maxHeight: .infinity)
                } else {
                    // @note results list (app/command results start at index 0 if no calc, or after calc)
                    if currentResults.isEmpty && !searchText.isEmpty && calculatorResult == nil {
                        // @note empty state when a query matches nothing
                        Text("No items with name '\(searchText)'")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ResultsListView(
                            results: currentResults,
                            selectedIndex: Binding(
                                get: { selectedIndex },
                                set: { selectedIndex = $0 }
                            ),
                            onSelect: { result in
                                handleResultSelection(result)
                            }
                        )
                    }
                }
                
                // @note footer (shown when typing or has results)
                if showFooter {
                    if mode == .emoji || mode == .clipboard {
                        Spacer(minLength: 0)
                    }
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                    
                    SearchFooterView(
                        showMenu: $showFooterMenu,
                        enableTransparency: settings.enableTransparency,
                        actionText: footerActionText
                    )
                }
            }
            
            if mode == .emoji && showEmojiCategoryMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showEmojiCategoryMenu = false
                    }
            }
            
            // @note dismiss footer menu when clicking elsewhere
            if showFooterMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showFooterMenu = false
                    }
            }
            
            // @note dismiss clipboard type menu when clicking elsewhere
            if mode == .clipboard && showClipboardTypeMenu {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showClipboardTypeMenu = false
                    }
            }
            
            // @note floating footer menu box, anchored bottom-left above the footer
            if showFooterMenu {
                FooterMenuBox(onSettings: {
                    showFooterMenu = false
                    openSettings()
                })
                .padding(.leading, 8)
                .padding(.bottom, 52)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            
            if mode == .emoji {
                emojiCategoryDropdown
                    .padding(.trailing, 16)
                    .padding(.top, 14)
            }
            
            if mode == .clipboard {
                clipboardTypeFilter
                    .padding(.trailing, 16)
                    .padding(.top, 14)
            }
        }
        .frame(width: 680, height: panelHeight, alignment: .top)
        .background {
            if settings.enableTransparency {
                ZStack {
                    VisualEffectBackground(
                        material: .hudWindow,
                        blendingMode: .behindWindow,
                        cornerRadius: 12,
                        opacity: 1.0
                    )
                    
                    RoundedRectangle(cornerRadius: 12)
                        .fill(backgroundOverlayColor)
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(solidBackgroundColor)
            }
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onChange(of: searchText) { newValue in
            // @note limit input length to prevent performance issues
            let maxInputLength = 100
            if newValue.count > maxInputLength {
                searchText = String(newValue.prefix(maxInputLength))
                return
            }
            
            if mode == .emoji {
                updateEmojiResults(query: newValue)
                calculatorWorkItem?.cancel()
                calculatorResult = nil
                selectedIndex = 0
                showCopiedFeedback = false
            } else if mode == .clipboard {
                clipboardService.search(query: newValue)
                calculatorWorkItem?.cancel()
                calculatorResult = nil
                selectedIndex = 0
                showCopiedFeedback = false
            } else {
                // @note always search (empty query returns top apps)
                searchService.search(query: newValue)
                
                if newValue.isEmpty {
                    calculatorWorkItem?.cancel()
                    calculatorResult = nil
                    selectedIndex = 0
                    showCopiedFeedback = false
                } else {
                    // @note cancel previous calculator work
                    calculatorWorkItem?.cancel()
                    
                    // @note evaluate calculator expression with debounce
                    let query = newValue
                    let workItem = DispatchWorkItem {
                        let calcResult = CalculatorService.shared.evaluate(query)
                        DispatchQueue.main.async {
                            // @note only update if search text hasn't changed
                            guard searchText == query else { return }
                            calculatorResult = calcResult
                            // @note reset selection: -1 if calculator result exists, 0 otherwise
                            if calcResult != nil && selectedIndex >= 0 {
                                selectedIndex = -1
                            } else if calcResult == nil && selectedIndex < 0 {
                                selectedIndex = 0
                            }
                        }
                    }
                    calculatorWorkItem = workItem
                    DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + .milliseconds(80), execute: workItem)
                    
                    showCopiedFeedback = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .saciWindowWillShow)) { _ in
            // @note show top apps when window opens
            if mode == .search {
                searchService.search(query: "")
                selectedIndex = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .saciWindowDidHide)) { _ in
            // @note clear search when window is hidden
            resetStateOnHide()
        }
        .onReceive(NotificationCenter.default.publisher(for: .emojiLibraryRequested)) { _ in
            enterEmojiLibrary()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clipboardHistoryRequested)) { _ in
            enterClipboardHistory()
        }
        .onReceive(emojiService.$emojis) { _ in
            if mode == .emoji {
                updateEmojiResults(query: searchText)
            }
        }
        .onReceive(emojiService.$categories) { categories in
            if !categories.isEmpty {
                emojiCategories = categories
                if !categories.contains(where: { $0.id == emojiSelectedCategoryId }) {
                    emojiSelectedCategoryId = EmojiCategory.all.id
                }
                if mode == .emoji {
                    updateEmojiResults(query: searchText)
                }
            }
        }
    }
    
    // @note command results for the launcher
    private var commandResults: [SearchResult] {
        let commands = [
            SearchResult.emojiLibraryCommandShared,
            SearchResult.clipboardHistoryCommandShared
        ]
        if searchText.isEmpty {
            return commands
        }
        return FuzzySearchService.search(query: searchText, in: commands, limit: commands.count)
    }
    
    // @note combined results list (commands + apps), uncapped
    // @note computed so it always reflects the latest query and app results
    private var currentResults: [SearchResult] {
        commandResults + searchService.results
    }
    
    // @note placeholder based on current launcher mode
    private var searchPlaceholder: String {
        switch mode {
        case .search: return "Search..."
        case .emoji: return "Search emojis..."
        case .clipboard: return "Search clipboard history..."
        }
    }
    
    // @note fixed height only for expanded modes
    private var panelHeight: CGFloat? {
        switch mode {
        case .search: return nil
        case .emoji: return emojiPanelHeight
        case .clipboard: return clipboardPanelHeight
        }
    }
    
    // @note current selected result if valid
    private var selectedResult: SearchResult? {
        guard isValidResultIndex(selectedIndex) else { return nil }
        return currentResults[selectedIndex]
    }
    
    // @note emoji grid columns
    private var emojiGridColumns: [GridItem] {
        Array(repeating: GridItem(.fixed(72), spacing: 8), count: 8)
    }
    
    // @note selected emoji category
    private var selectedEmojiCategory: EmojiCategory {
        emojiCategories.first(where: { $0.id == emojiSelectedCategoryId }) ?? EmojiCategory.all
    }
    
    // @note emoji category dropdown menu
    private var emojiCategoryButton: some View {
        Button(action: { showEmojiCategoryMenu.toggle() }) {
            HStack(spacing: 6) {
                Text(selectedEmojiCategory.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer(minLength: 6)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(width: emojiDropdownWidth, height: emojiDropdownHeight)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // @note emoji category dropdown list
    private var emojiCategoryList: some View {
        EmojiCategoryListView(
            categories: emojiCategories,
            selectedCategoryId: $emojiSelectedCategoryId,
            onSelect: {
                updateEmojiResults(query: searchText)
                showEmojiCategoryMenu = false
            }
        )
        .frame(width: 220, height: 260)
        .background(dropdownBackgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(dropdownBorderColor, lineWidth: 1)
        )
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
    }
    
    // @note emoji category dropdown container
    private var emojiCategoryDropdown: some View {
        VStack(alignment: .trailing, spacing: 6) {
            emojiCategoryButton
            
            if showEmojiCategoryMenu {
                emojiCategoryList
            }
        }
    }
    
    // @note get valid max index for current results (considering calculator)
    private var validMaxIndex: Int {
        currentResults.isEmpty ? -1 : currentResults.count - 1
    }
    
    // @note check if index is valid for current results
    // @param index index to validate
    private func isValidResultIndex(_ index: Int) -> Bool {
        !currentResults.isEmpty && index >= 0 && index <= validMaxIndex
    }
    
    // @note handle arrow up
    private func handleArrowUp() -> Bool {
        if mode == .clipboard && showClipboardActions {
            moveActionSelection(by: -1)
            return true
        }
        if mode == .search {
            moveSelection(by: -1)
            return true
        }
        if mode == .clipboard {
            moveClipboardSelection(by: -1)
            return true
        }
        return false
    }
    
    // @note handle arrow down
    private func handleArrowDown() -> Bool {
        if mode == .clipboard && showClipboardActions {
            moveActionSelection(by: 1)
            return true
        }
        if mode == .search {
            moveSelection(by: 1)
            return true
        }
        if mode == .clipboard {
            moveClipboardSelection(by: 1)
            return true
        }
        return false
    }
    
    // @note handle escape key
    private func handleEscape() {
        if mode == .clipboard && showClipboardActions {
            showClipboardActions = false
            return
        }
        if mode == .emoji {
            exitEmojiLibrary()
        } else if mode == .clipboard {
            hideWindow()
        } else {
            hideWindow()
        }
    }
    
    private func handleLeftArrow() -> Bool {
        return false
    }
    
    private func handleRightArrow() -> Bool {
        return false
    }
    
    // @note move selection up or down
    // @param delta direction to move (-1 up, 1 down)
    private func moveSelection(by delta: Int) {
        let hasCalc = calculatorResult != nil
        let hasResults = !currentResults.isEmpty
        
        guard hasCalc || hasResults else { return }
        
        let minIndex = hasCalc ? -1 : 0
        let maxIndex = hasResults ? validMaxIndex : -1
        
        selectedIndex = max(minIndex, min(maxIndex, selectedIndex + delta))
    }
    
    // @note handle submit action (copy calc, emoji, or launch)
    private func handleSubmit() {
        if mode == .emoji { return }
        if mode == .clipboard {
            if showClipboardActions {
                runSelectedClipboardAction()
                return
            }
            // @note Enter copies the selected entry, closes, and moves it to the top (no auto-paste)
            executeClipboardAction(.copy)
            return
        }
        if isCalculatorSelected {
            copyCalculatorResult()
        } else {
            launchSelectedResult()
        }
    }
    
    // @note handle selection in results list
    // @param result selected result
    private func handleResultSelection(_ result: SearchResult) {
        switch result.kind {
        case .command:
            switch result.path {
            case SearchResult.clipboardHistoryCommandShared.path:
                enterClipboardHistory()
            default:
                enterEmojiLibrary()
            }
        case .app:
            searchService.launchApp(at: result.path)
            hideWindow()
        }
    }
    
    // @note launch the currently selected result
    private func launchSelectedResult() {
        guard isValidResultIndex(selectedIndex) else { return }
        let result = currentResults[selectedIndex]
        handleResultSelection(result)
    }
    
    // @note launch result at specific index (modifier+number shortcut)
    // @param index 0-based index of the result in list
    private func launchAppAtIndex(_ index: Int) {
        guard mode == .search, isValidResultIndex(index) else { return }
        let result = currentResults[index]
        handleResultSelection(result)
    }
    
    // @note move clipboard selection up or down
    // @param delta direction to move (-1 up, 1 down)
    private func moveClipboardSelection(by delta: Int) {
        guard !clipboardService.results.isEmpty else { return }
        let maxIndex = clipboardService.results.count - 1
        selectedIndex = max(0, min(maxIndex, selectedIndex + delta))
    }
    
    // @note move action box selection up or down
    // @param delta direction to move (-1 up, 1 down)
    private func moveActionSelection(by delta: Int) {
        let count = ClipboardAction.allCases.count
        clipboardActionIndex = (clipboardActionIndex + delta + count) % count
    }
    
    // @note run the action currently highlighted in the actions box
    private func runSelectedClipboardAction() {
        let actions = ClipboardAction.allCases
        guard clipboardActionIndex >= 0, clipboardActionIndex < actions.count else { return }
        executeClipboardAction(actions[clipboardActionIndex])
    }
    
    // @note dispatch a clipboard action against the currently selected entry
    // @param action action to perform
    private func executeClipboardAction(_ action: ClipboardAction) {
        // @note clear-all does not require a selected entry
        if action == .clearAll {
            clipboardService.clearHistory()
            selectedIndex = 0
            showClipboardActions = false
            return
        }
        guard selectedIndex >= 0, selectedIndex < clipboardService.results.count else { return }
        let entry = clipboardService.results[selectedIndex]
        showClipboardActions = false
        switch action {
        case .paste:
            clipboardPaste(entry)
        case .copy:
            clipboardCopy(entry)
        case .pin:
            clipboardService.togglePin(entry)
        case .share:
            clipboardShare(entry)
        case .delete:
            clipboardDelete(entry)
        case .clearAll:
            break
        }
    }
    
    // @note restore selected clipboard entry (paste action)
    private func restoreSelectedClipboardEntry() {
        guard selectedIndex >= 0 && selectedIndex < clipboardService.results.count else { return }
        clipboardPaste(clipboardService.results[selectedIndex])
    }
    
    // @note copy clipboard history entry back to pasteboard
    // @param entry clipboard entry to restore
    private func restoreClipboardEntry(_ entry: ClipboardEntry) {
        clipboardService.restore(entry)
        hideWindow()
    }
    
    // @note paste action: copy entry to pasteboard, hide, then paste into the previous app
    // @param entry clipboard entry to paste
    private func clipboardPaste(_ entry: ClipboardEntry) {
        clipboardService.restore(entry)
        hideWindow()
        // @note give focus time to return to the previous app, then synthesize Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            Self.simulatePaste()
        }
    }
    
    // @note copy entry to the clipboard and close (no auto-paste)
    // @param entry clipboard entry to copy
    private func clipboardCopy(_ entry: ClipboardEntry) {
        clipboardService.restore(entry)
        hideWindow()
    }
    
    // @note delete an entry and keep the selection in bounds
    // @param entry clipboard entry to delete
    private func clipboardDelete(_ entry: ClipboardEntry) {
        clipboardService.delete(entry)
        let count = clipboardService.results.count
        if count == 0 {
            selectedIndex = 0
        } else if selectedIndex >= count {
            selectedIndex = count - 1
        }
    }
    
    // @note share an entry via the system share sheet
    // @param entry clipboard entry to share
    private func clipboardShare(_ entry: ClipboardEntry) {
        var items: [Any] = []
        if entry.type == .image, let image = clipboardService.image(for: entry) {
            items = [image]
        } else {
            items = [entry.content]
        }
        guard !items.isEmpty, let view = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
    }
    
    // @note synthesize a Cmd+V keystroke to paste into the frontmost app
    private static func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        keyVDown?.flags = .maskCommand
        let keyVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyVUp?.flags = .maskCommand
        keyVDown?.post(tap: .cghidEventTap)
        keyVUp?.post(tap: .cghidEventTap)
    }
    
    // @note clipboard type filter custom dropdown (All Types / Text / Link / Image)
    private var clipboardTypeFilter: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Button(action: { showClipboardTypeMenu.toggle() }) {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 11, weight: .medium))
                    Text(clipboardService.typeFilter?.displayName ?? "All Types")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .rotationEffect(.degrees(showClipboardTypeMenu ? 180 : 0))
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(clipboardFilterBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .fixedSize()
            
            if showClipboardTypeMenu {
                clipboardTypeList
            }
        }
    }
    
    // @note dropdown list of type options
    private var clipboardTypeList: some View {
        VStack(spacing: 2) {
            clipboardTypeRow("All Types", type: nil, icon: "square.grid.2x2")
            clipboardTypeRow("Text", type: .text, icon: "doc.text")
            clipboardTypeRow("Link", type: .url, icon: "link")
            clipboardTypeRow("Image", type: .image, icon: "photo")
        }
        .padding(6)
        .frame(width: 168)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dropdownBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(dropdownBorderColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
    }
    
    // @note a single type filter row
    private func clipboardTypeRow(_ title: String, type: ClipboardItemType?, icon: String) -> some View {
        ClipboardTypeRow(
            title: title,
            icon: icon,
            isSelected: clipboardService.typeFilter == type
        ) {
            setClipboardTypeFilter(type)
            showClipboardTypeMenu = false
        }
    }
    
    // @note darker background behind the type filter
    private var clipboardFilterBackground: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.0, alpha: 0.28))
            : Color(nsColor: NSColor(white: 0.0, alpha: 0.08))
    }
    
    // @note apply a type filter and reset selection
    // @param type type to filter by, or nil for all
    private func setClipboardTypeFilter(_ type: ClipboardItemType?) {
        clipboardService.setTypeFilter(type)
        selectedIndex = 0
    }
    
    // @note copy calculator result to clipboard
    private func copyCalculatorResult() {
        guard let calcResult = calculatorResult else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(calcResult.copyValue, forType: .string)
        
        // @note show feedback
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopiedFeedback = true
        }
        
        // @note hide feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedFeedback = false
            }
        }
    }
    
    // @note update emoji results for query
    private func updateEmojiResults(query: String) {
        let category = selectedEmojiCategory
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let baseEntries: [EmojiEntry]
        switch category.kind {
        case .all:
            baseEntries = emojiService.emojis
        case .frequent:
            baseEntries = emojiService.frequentEntries(limit: 200)
        case .group:
            if let key = category.groupKey {
                baseEntries = emojiService.groupedEmojis[key] ?? []
            } else {
                baseEntries = []
            }
        case .subgroup:
            if let subgroup = category.subgroup {
                baseEntries = emojiService.subgroupedEmojis[subgroup] ?? []
            } else {
                baseEntries = []
            }
        }
        
        if normalized.isEmpty {
            var sections: [EmojiSectionData] = []
            var offset = 0
            
            if category.kind == .all || category.kind == .frequent {
                let frequent = emojiService.frequentEntries(limit: 16)
                if !frequent.isEmpty {
                    sections.append(
                        EmojiSectionData(
                            id: "frequent",
                            title: "Frequently Used",
                            entries: frequent,
                            offset: offset
                        )
                    )
                    offset += frequent.count
                }
            }
            
            if category.kind == .all {
                for key in EmojiGroupKey.allCases {
                    let entries = emojiService.groupedEmojis[key] ?? []
                    if entries.isEmpty { continue }
                    sections.append(
                        EmojiSectionData(
                            id: "group-\(key.rawValue)",
                            title: key.displayName,
                            entries: entries,
                            offset: offset
                        )
                    )
                    offset += entries.count
                }
            } else if category.kind == .group {
                if !baseEntries.isEmpty, let key = category.groupKey {
                    sections.append(
                        EmojiSectionData(
                            id: "group-\(key.rawValue)",
                            title: key.displayName,
                            entries: baseEntries,
                            offset: offset
                        )
                    )
                }
            } else if category.kind == .subgroup {
                if !baseEntries.isEmpty, let subgroup = category.subgroup {
                    sections.append(
                        EmojiSectionData(
                            id: "subgroup-\(subgroup)",
                            title: subgroup,
                            entries: baseEntries,
                            offset: offset
                        )
                    )
                }
            }
            
            setEmojiSections(sections)
        } else {
            emojiService.search(query: normalized, in: baseEntries) { results in
                let sections = [
                    EmojiSectionData(
                        id: "search",
                        title: "",
                        entries: results,
                        offset: 0
                    )
                ]
                setEmojiSections(sections)
            }
        }
    }
    
    // @note set emoji sections and update selection
    private func setEmojiSections(_ sections: [EmojiSectionData]) {
        emojiSections = sections
        emojiDisplayEntries = sections.flatMap { $0.entries }
    }
    
    // @note copy emoji entry to clipboard
    // @param entry emoji entry to copy
    private func copyEmoji(_ entry: EmojiEntry, token: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.emoji, forType: .string)
        emojiService.recordUsage(entry.emoji)
        copiedEmojiToken = token
        
        if mode == .emoji && searchText.isEmpty {
            let kind = selectedEmojiCategory.kind
            if kind == .all || kind == .frequent {
                updateEmojiResults(query: searchText)
            }
        }
        
        let currentToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if copiedEmojiToken == currentToken {
                copiedEmojiToken = nil
            }
        }
    }
    
    // @note enter emoji library mode
    private func enterEmojiLibrary() {
        mode = .emoji
        searchText = ""
        calculatorWorkItem?.cancel()
        calculatorResult = nil
        selectedIndex = 0
        showCopiedFeedback = false
        showEmojiCategoryMenu = false
        copiedEmojiToken = nil
        emojiSelectedCategoryId = EmojiCategory.all.id
        emojiService.loadIfNeeded()
        updateEmojiResults(query: "")
        NotificationCenter.default.post(name: .emojiLibraryDidEnter, object: nil)
    }
    
    // @note exit emoji library mode
    private func exitEmojiLibrary() {
        mode = .search
        searchText = ""
        calculatorWorkItem?.cancel()
        calculatorResult = nil
        selectedIndex = 0
        emojiSections = []
        emojiDisplayEntries = []
        showCopiedFeedback = false
        showEmojiCategoryMenu = false
        copiedEmojiToken = nil
        searchService.search(query: "")
        NotificationCenter.default.post(name: .emojiLibraryDidExit, object: nil)
    }
    
    // @note enter clipboard history mode
    private func enterClipboardHistory() {
        mode = .clipboard
        searchText = ""
        calculatorWorkItem?.cancel()
        calculatorResult = nil
        selectedIndex = 0
        showCopiedFeedback = false
        showEmojiCategoryMenu = false
        copiedEmojiToken = nil
        showClipboardActions = false
        clipboardActionIndex = 0
        showClipboardTypeMenu = false
        clipboardService.setTypeFilter(nil)
        clipboardService.search(query: "")
        NotificationCenter.default.post(name: .clipboardHistoryDidEnter, object: nil)
    }
    
    // @note exit clipboard history mode
    private func exitClipboardHistory() {
        mode = .search
        searchText = ""
        calculatorWorkItem?.cancel()
        calculatorResult = nil
        selectedIndex = 0
        showCopiedFeedback = false
        clipboardService.clearResults()
        searchService.search(query: "")
        NotificationCenter.default.post(name: .clipboardHistoryDidExit, object: nil)
    }
    
    // @note reset state when window hides
    private func resetStateOnHide() {
        mode = .search
        searchText = ""
        selectedIndex = 0
        calculatorWorkItem?.cancel()
        calculatorResult = nil
        emojiSections = []
        emojiDisplayEntries = []
        clipboardService.clearResults()
        showCopiedFeedback = false
        showEmojiCategoryMenu = false
        showFooterMenu = false
        showClipboardActions = false
        showClipboardTypeMenu = false
        copiedEmojiToken = nil
        searchService.clearResults()
        NotificationCenter.default.post(name: .emojiLibraryDidExit, object: nil)
    }
    
    // @note hide the main window
    private func hideWindow() {
        searchText = ""
        selectedIndex = 0
        calculatorResult = nil
        showCopiedFeedback = false
        onEscape?()
    }
    
    // @note open settings
    private func openSettings() {
        onOpenSettings?()
    }
}

// @note custom NSTextField wrapper that handles key events properly
struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var rightPadding: CGFloat
    var colorScheme: ColorScheme
    var enableTransparency: Bool
    var onEscape: () -> Void
    var onLeftArrow: () -> Bool
    var onRightArrow: () -> Bool
    var onArrowUp: () -> Bool
    var onArrowDown: () -> Bool
    var onSubmit: () -> Void
    var onCommandComma: () -> Void
    var onCommandNumber: (Int) -> Void
    // @note clipboard-mode shortcuts (return true when handled)
    var onCommandK: () -> Bool = { false }
    var onCommandC: () -> Bool = { false }
    var onCommandP: () -> Bool = { false }
    var onControlX: () -> Bool = { false }
    var onCommandShiftDelete: () -> Bool = { false }
    
    func makeNSView(context: Context) -> NSView {
        let containerView = SaciSearchContainerView()
        containerView.wantsLayer = true
        updateContainerAppearance(containerView)
        
        let imageView = NSImageView()
        imageView.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        imageView.contentTintColor = .secondaryLabelColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let textField = SaciTextField()
        textField.delegate = context.coordinator
        textField.onEscape = onEscape
        textField.onLeftArrow = onLeftArrow
        textField.onRightArrow = onRightArrow
        textField.onArrowUp = onArrowUp
        textField.onArrowDown = onArrowDown
        textField.onCommandComma = onCommandComma
        textField.onCommandNumber = onCommandNumber
        textField.onCommandK = onCommandK
        textField.onCommandC = onCommandC
        textField.onCommandP = onCommandP
        textField.onControlX = onControlX
        textField.onCommandShiftDelete = onCommandShiftDelete
        textField.stringValue = text
        textField.placeholderString = placeholder
        textField.isBordered = false
        textField.drawsBackground = false
        textField.font = NSFont.systemFont(ofSize: 24, weight: .light)
        textField.textColor = .labelColor
        textField.focusRingType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.cell?.sendsActionOnEndEditing = false
        
        containerView.addSubview(imageView)
        containerView.addSubview(textField)
        
        let trailingConstraint = textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -rightPadding)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            imageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalToConstant: 22),
            
            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            trailingConstraint,
            textField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            containerView.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        context.coordinator.textField = textField
        context.coordinator.imageView = imageView
        context.coordinator.containerView = containerView
        context.coordinator.trailingConstraint = trailingConstraint
        
        // @note observe window becoming key to focus text field
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.windowDidBecomeKey),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        
        return containerView
    }
    
    // @note update container background based on color scheme and transparency
    private func updateContainerAppearance(_ containerView: NSView) {
        if enableTransparency {
            containerView.layer?.backgroundColor = NSColor.clear.cgColor
        } else {
            let bgColor = colorScheme == .dark
                ? NSColor(white: 0.15, alpha: 1)
                : NSColor(white: 0.9, alpha: 1)
            containerView.layer?.backgroundColor = bgColor.cgColor
        }
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // @note keep the coordinator's parent current so its text binding and callbacks aren't stale
        context.coordinator.parent = self
        
        if let textField = context.coordinator.textField {
            if textField.stringValue != text {
                textField.stringValue = text
            }
            textField.onEscape = onEscape
            textField.onLeftArrow = onLeftArrow
            textField.onRightArrow = onRightArrow
            textField.onArrowUp = onArrowUp
            textField.onArrowDown = onArrowDown
            textField.onCommandComma = onCommandComma
            textField.onCommandNumber = onCommandNumber
            textField.onCommandK = onCommandK
            textField.onCommandC = onCommandC
            textField.onCommandP = onCommandP
            textField.onControlX = onControlX
            textField.onCommandShiftDelete = onCommandShiftDelete
            textField.textColor = .labelColor
            textField.placeholderString = placeholder
        }
        
        if let constraint = context.coordinator.trailingConstraint {
            constraint.constant = -rightPadding
        }
        
        // @note update appearance when color scheme changes
        updateContainerAppearance(nsView)
        context.coordinator.imageView?.contentTintColor = .secondaryLabelColor
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchTextField
        weak var textField: SaciTextField?
        weak var imageView: NSImageView?
        weak var containerView: NSView?
        var trailingConstraint: NSLayoutConstraint?
        
        init(_ parent: SearchTextField) {
            self.parent = parent
        }
        
        @objc func windowDidBecomeKey(_ notification: Notification) {
            // @note focus text field when window becomes key
            DispatchQueue.main.async { [weak self] in
                guard let textField = self?.textField else { return }
                textField.window?.makeFirstResponder(textField)
            }
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                return parent.onArrowUp()
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                return parent.onArrowDown()
            }
            return false
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// @note emoji category list view
private struct EmojiCategoryListView: View {
    let categories: [EmojiCategory]
    @Binding var selectedCategoryId: String
    var onSelect: () -> Void
    @State private var hoveredCategoryId: String?
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(categories) { category in
                    EmojiCategoryRow(
                        title: category.title,
                        isSelected: category.id == selectedCategoryId,
                        isHovered: hoveredCategoryId == category.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCategoryId = category.id
                        onSelect()
                    }
                    .onHover { hovering in
                        hoveredCategoryId = hovering ? category.id : nil
                    }
                }
            }
            .padding(8)
        }
    }
}

private struct EmojiCategoryRow: View {
    let title: String
    let isSelected: Bool
    let isHovered: Bool
    
    private var rowBackground: Color {
        if isSelected {
            return Color.secondary.opacity(0.2)
        }
        if isHovered {
            return Color.secondary.opacity(0.12)
        }
        return Color.clear
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(rowBackground)
        )
    }
}

// @note container view that updates appearance
class SaciSearchContainerView: NSView {
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // @note trigger redraw when appearance changes
        needsDisplay = true
    }
}

// @note custom NSTextField that intercepts key events
class SaciTextField: NSTextField {
    var onEscape: (() -> Void)?
    var onLeftArrow: (() -> Bool)?
    var onRightArrow: (() -> Bool)?
    var onArrowUp: (() -> Bool)?
    var onArrowDown: (() -> Bool)?
    var onCommandComma: (() -> Void)?
    var onCommandNumber: ((Int) -> Void)?
    var onCommandK: (() -> Bool)?
    var onCommandC: (() -> Bool)?
    var onCommandP: (() -> Bool)?
    var onControlX: (() -> Bool)?
    var onCommandShiftDelete: (() -> Bool)?
    
    // @note number key codes (1-9) for quick app launch
    private let numberKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
        22: 6, 26: 7, 28: 8, 25: 9
    ]
    
    // @note handle key shortcuts before they reach the system
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // @note handle ESC key
        if event.keyCode == 53 {
            onEscape?()
            return true
        }
        
        // @note Control+X (delete entry, clipboard mode)
        if event.modifierFlags.contains(.control),
           event.charactersIgnoringModifiers?.lowercased() == "x" {
            if onControlX?() == true { return true }
        }
        
        if event.modifierFlags.contains(.command) {
            // @note handle Cmd+, for settings
            if event.charactersIgnoringModifiers == "," {
                onCommandComma?()
                return true
            }
            
            // @note Cmd+Shift+Delete (clear all history, clipboard mode)
            if event.modifierFlags.contains(.shift), event.keyCode == 51 {
                if onCommandShiftDelete?() == true { return true }
            }
            
            // @note handle Cmd+number (1-9) for quick app launch
            if let number = numberKeyCodes[event.keyCode] {
                onCommandNumber?(number - 1) // convert to 0-based index
                return true
            }
            
            // @note clipboard-mode command shortcuts (only handled in clipboard mode)
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "k":
                if onCommandK?() == true { return true }
            case "c":
                if onCommandC?() == true { return true }
            case "p":
                if onCommandP?() == true { return true }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // escape
            onEscape?()
            return
        case 123: // left arrow
            if onLeftArrow?() == true {
                return
            }
        case 124: // right arrow
            if onRightArrow?() == true {
                return
            }
        case 126: // up arrow
            if onArrowUp?() == true {
                return
            }
        case 125: // down arrow
            if onArrowDown?() == true {
                return
            }
        default:
            break
        }
        
        super.keyDown(with: event)
    }
    
    override var acceptsFirstResponder: Bool { true }
    
    override func becomeFirstResponder() -> Bool {
        let success = super.becomeFirstResponder()
        // @note select all text when becoming first responder
        if success {
            currentEditor()?.selectAll(nil)
        }
        return success
    }
}

#Preview {
    ContentView()
}
