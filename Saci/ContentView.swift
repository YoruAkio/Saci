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
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// @note footer menu button with popup
struct FooterMenuButton: View {
    @State private var showMenu = false
    var onSettings: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private var menuBackgroundColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.15, alpha: 1))
            : Color(nsColor: NSColor(white: 0.92, alpha: 1))
    }
    
    var body: some View {
        Button(action: { showMenu.toggle() }) {
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
        .popover(isPresented: $showMenu, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                // @note version header
                Text("Saci v0.1.0-alpha")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                
                Divider()
                
                // @note settings button
                Button(action: {
                    showMenu = false
                    onSettings()
                }) {
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.clear)
                .onHover { hovering in
                    // @note handled by system
                }
            }
            .frame(width: 200)
            .background(menuBackgroundColor)
        }
    }
}

// @note search window footer bar
struct SearchFooterView: View {
    var onSettings: () -> Void
    var enableTransparency: Bool
    var actionText: String = "Open Application"
    @Environment(\.colorScheme) var colorScheme
    
    // @note semi-transparent overlay color above the blur
    private var footerOverlayColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.08, alpha: 0.6))
            : Color(nsColor: NSColor(white: 0.85, alpha: 0.6))
    }
    
    // @note solid background when transparency disabled
    private var footerSolidColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.1, alpha: 1))
            : Color(nsColor: NSColor(white: 0.88, alpha: 1))
    }
    
    var body: some View {
        HStack(spacing: 8) {
            FooterMenuButton(onSettings: onSettings)
            
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

// @note main search window UI
struct ContentView: View {
    @StateObject private var searchService = AppSearchService()
    @ObservedObject private var settings = AppSettings.shared
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var showSettings = false
    @State private var calculatorResult: CalculatorResult?
    @State private var showCopiedFeedback = false
    @Environment(\.colorScheme) var colorScheme
    
    var onEscape: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    
    init(onEscape: (() -> Void)? = nil, onOpenSettings: (() -> Void)? = nil) {
        self.onEscape = onEscape
        self.onOpenSettings = onOpenSettings
    }
    
    // @note check if calculator result is selected (index -1 means calculator)
    private var isCalculatorSelected: Bool {
        calculatorResult != nil && selectedIndex == -1
    }
    
    // @note check if footer should be visible
    private var showFooter: Bool {
        !searchService.results.isEmpty || calculatorResult != nil
    }
    
    // @note total selectable items (calculator + app results)
    private var totalSelectableItems: Int {
        let calcCount = calculatorResult != nil ? 1 : 0
        let appCount = min(searchService.results.count, settings.maxResults)
        return calcCount + appCount
    }
    
    // @note footer action text based on selection
    private var footerActionText: String {
        if isCalculatorSelected {
            return "Copy Result"
        }
        return "Open Application"
    }
    
    // @note background color based on theme (used when transparency disabled)
    private var solidBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(nsColor: NSColor(white: 0.12, alpha: 1))
            : Color(nsColor: NSColor(white: 0.95, alpha: 1))
    }
    
    // @note divider color based on theme
    private var dividerColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.8, alpha: 1))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // @note search bar
            SearchTextField(
                text: $searchText,
                colorScheme: colorScheme,
                enableTransparency: settings.enableTransparency,
                onEscape: {
                    hideWindow()
                },
                onArrowUp: {
                    moveSelection(by: -1)
                },
                onArrowDown: {
                    moveSelection(by: 1)
                },
                onSubmit: {
                    handleSubmit()
                },
                onCommandComma: {
                    openSettings()
                },
                onCommandNumber: { index in
                    launchAppAtIndex(index)
                }
            )
            
            // @note divider
            if !searchService.results.isEmpty || calculatorResult != nil {
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
            }
            
            // @note calculator result (shown above app results)
            if let calcResult = calculatorResult {
                CalculatorResultContainer(
                    result: calcResult,
                    isSelected: isCalculatorSelected,
                    showCopied: showCopiedFeedback,
                    onCopy: copyCalculatorResult
                )
                
                // @note divider between calculator and app results
                if !searchService.results.isEmpty {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            }
            
            // @note results list (app results start at index 0 if no calc, or after calc)
            ResultsListView(
                results: searchService.results,
                selectedIndex: Binding(
                    get: { calculatorResult != nil ? selectedIndex : selectedIndex },
                    set: { selectedIndex = $0 }
                ),
                onSelect: { result in
                    searchService.launchApp(at: result.path)
                    hideWindow()
                },
                maxResults: settings.maxResults
            )
            
            // @note footer (shown when typing or has results)
            if showFooter {
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
                
                SearchFooterView(
                    onSettings: openSettings,
                    enableTransparency: settings.enableTransparency,
                    actionText: footerActionText
                )
            }
        }
        .frame(width: 680)
        .background {
            if settings.enableTransparency {
                VisualEffectBackground(
                    material: .hudWindow,
                    blendingMode: .behindWindow,
                    cornerRadius: 12
                )
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
            
            // @note clear calculator result if search text is empty
            if newValue.isEmpty {
                calculatorResult = nil
                selectedIndex = 0
                showCopiedFeedback = false
            } else {
                searchService.search(query: newValue)
                // @note evaluate calculator expression
                calculatorResult = CalculatorService.shared.evaluate(newValue)
                // @note reset selection: -1 if calculator result exists, 0 otherwise
                selectedIndex = calculatorResult != nil ? -1 : 0
                showCopiedFeedback = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .saciWindowDidHide)) { _ in
            // @note clear search when window is hidden
            searchText = ""
            selectedIndex = 0
            calculatorResult = nil
            showCopiedFeedback = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .saciWindowWillShow)) { _ in
            // @note ensure clean state when window appears
            if searchText.isEmpty {
                calculatorResult = nil
                selectedIndex = 0
                showCopiedFeedback = false
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
    }
    
    // @note get valid max index for current results (considering calculator)
    private var validMaxIndex: Int {
        let appMaxIndex = min(searchService.results.count, settings.maxResults) - 1
        return appMaxIndex
    }
    
    // @note get minimum selection index (-1 if calculator exists, 0 otherwise)
    private var minSelectionIndex: Int {
        calculatorResult != nil ? -1 : 0
    }
    
    // @note check if index is valid for current app results
    // @param index index to validate
    private func isValidAppIndex(_ index: Int) -> Bool {
        !searchService.results.isEmpty && index >= 0 && index <= validMaxIndex
    }
    
    // @note move selection up or down
    // @param delta direction to move (-1 up, 1 down)
    private func moveSelection(by delta: Int) {
        let hasCalc = calculatorResult != nil
        let hasApps = !searchService.results.isEmpty
        
        guard hasCalc || hasApps else { return }
        
        let minIndex = hasCalc ? -1 : 0
        let maxIndex = hasApps ? validMaxIndex : -1
        
        selectedIndex = max(minIndex, min(maxIndex, selectedIndex + delta))
    }
    
    // @note handle submit action (copy calc or launch app)
    private func handleSubmit() {
        if isCalculatorSelected {
            copyCalculatorResult()
        } else {
            launchSelectedApp()
        }
    }
    
    // @note launch the currently selected app
    private func launchSelectedApp() {
        guard isValidAppIndex(selectedIndex) else { return }
        let result = searchService.results[selectedIndex]
        searchService.launchApp(at: result.path)
        hideWindow()
    }
    
    // @note launch app at specific index (modifier+number shortcut)
    // @param index 0-based index of the app in results
    private func launchAppAtIndex(_ index: Int) {
        guard isValidAppIndex(index) else { return }
        let result = searchService.results[index]
        searchService.launchApp(at: result.path)
        hideWindow()
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
        if let onOpenSettings = onOpenSettings {
            onOpenSettings()
        } else {
            showSettings = true
        }
    }
}

// @note custom NSTextField wrapper that handles key events properly
struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    var colorScheme: ColorScheme
    var enableTransparency: Bool
    var onEscape: () -> Void
    var onArrowUp: () -> Void
    var onArrowDown: () -> Void
    var onSubmit: () -> Void
    var onCommandComma: () -> Void
    var onCommandNumber: (Int) -> Void
    
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
        textField.onArrowUp = onArrowUp
        textField.onArrowDown = onArrowDown
        textField.onCommandComma = onCommandComma
        textField.onCommandNumber = onCommandNumber
        textField.stringValue = text
        textField.placeholderString = "Search..."
        textField.isBordered = false
        textField.drawsBackground = false
        textField.font = NSFont.systemFont(ofSize: 24, weight: .light)
        textField.textColor = .labelColor
        textField.focusRingType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.cell?.sendsActionOnEndEditing = false
        
        containerView.addSubview(imageView)
        containerView.addSubview(textField)
        
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            imageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 22),
            imageView.heightAnchor.constraint(equalToConstant: 22),
            
            textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            textField.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            containerView.heightAnchor.constraint(equalToConstant: 56)
        ])
        
        context.coordinator.textField = textField
        context.coordinator.imageView = imageView
        context.coordinator.containerView = containerView
        
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
        if let textField = context.coordinator.textField {
            if textField.stringValue != text {
                textField.stringValue = text
            }
            textField.onEscape = onEscape
            textField.onArrowUp = onArrowUp
            textField.onArrowDown = onArrowDown
            textField.onCommandComma = onCommandComma
            textField.onCommandNumber = onCommandNumber
            textField.textColor = .labelColor
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
                parent.onArrowUp()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowDown()
                return true
            }
            return false
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
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
    var onArrowUp: (() -> Void)?
    var onArrowDown: (() -> Void)?
    var onCommandComma: (() -> Void)?
    var onCommandNumber: ((Int) -> Void)?
    
    // @note number key codes (1-9)
    private let numberKeyCodes: [UInt16: Int] = [
        18: 1, 19: 2, 20: 3, 21: 4, 23: 5,
        22: 6, 26: 7, 28: 8, 25: 9
    ]
    
    // @note handle Cmd+number shortcuts before they reach the system
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) {
            // @note handle Cmd+, for settings
            if event.charactersIgnoringModifiers == "," {
                onCommandComma?()
                return true
            }
            
            // @note handle Cmd+number (1-9) for quick app launch
            if let number = numberKeyCodes[event.keyCode] {
                onCommandNumber?(number - 1) // convert to 0-based index
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // escape
            onEscape?()
            return
        case 126: // up arrow
            onArrowUp?()
            return
        case 125: // down arrow
            onArrowDown?()
            return
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
