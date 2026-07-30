# AGENTS.md - Development Guide For Saci

## Project Overview

Saci is a powerful macOS productivity launcher that provides Spotlight-like functionality built using native Swift/SwiftUI, inspired by Alfred and Raycast.

- **Platform**: macOS 13.7+
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI with AppKit integration
- **Build System**: Xcode 15.2

## Build Commands

```bash
# Build the project
xcodebuild -project Saci.xcodeproj -scheme Saci -configuration Debug build CONFIGURATION_BUILD_DIR=./build

# Build for release
xcodebuild -project Saci.xcodeproj -scheme Saci -configuration Release build CONFIGURATION_BUILD_DIR=./build

# Clean build folder
xcodebuild -project Saci.xcodeproj -scheme Saci clean CONFIGURATION_BUILD_DIR=./build
```

## Code Style Guidelines

### File Header

Every Swift file should have this header format:

```swift
//
//  FileName.swift
//  Saci
//
```

### Imports

- One import per line
- Framework imports at top of file
- Order: SwiftUI/UIKit, then Apple frameworks, then third-party

```swift
import SwiftUI
import Carbon
import ServiceManagement
```

### Comments

Use lowercase comments with specific prefixes. Do not use periods at end:

```swift
// @note visual effect view for transparency/blur effect
// @todo add keyboard shortcut support
// @param query search text to filter
```

For functions with parameters:

```swift
// @note filter apps based on search query
// @param query search text to filter
func search(query: String) { }

// @note move selection up or down
// @param delta direction to move (-1 up, 1 down)
private func moveSelection(by delta: Int) { }
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Types/Classes | PascalCase | `AppSettings`, `SearchResult` |
| Protocols | PascalCase | `Identifiable`, `Hashable` |
| Variables/Properties | camelCase | `searchText`, `selectedIndex` |
| Functions | camelCase | `loadApps()`, `hideWindow()` |
| Enums | PascalCase | `AppTheme`, `HotkeyOption` |
| Enum cases | camelCase | `.system`, `.optionSpace` |
| Constants | camelCase | `maxResults` (not SCREAMING_SNAKE) |

### SwiftUI Property Wrappers

```swift
@StateObject private var searchService = AppSearchService()  // owned observable
@ObservedObject private var settings = AppSettings.shared    // passed-in observable
@State private var searchText = ""                           // local view state
@Environment(\.colorScheme) var colorScheme                  // system values
@AppStorage("maxResults") var maxResults: Int = 8            // UserDefaults
```

### Architecture Patterns

- **Singleton pattern** for shared services: `AppSettings.shared`, `HotkeyManager.shared`
- **MVVM-like** with ObservableObject services
- **NotificationCenter** for cross-component communication
- **NSViewRepresentable** for AppKit integration in SwiftUI

### Directory Structure

```
Saci/
├── SaciApp.swift           # App entry point & AppDelegate
├── ContentView.swift       # Main search window view
├── Views/                  # UI components
│   ├── SettingsView.swift
│   ├── SearchBarView.swift
│   ├── ResultRowView.swift
│   └── ResultsListView.swift
├── Models/                 # Data models
│   ├── AppSettings.swift
│   └── SearchResult.swift
├── Services/               # Business logic
│   ├── AppSearchService.swift
│   └── HotkeyManager.swift
└── Assets.xcassets/        # Images and colors
```

### Error Handling

- Use `try?` for recoverable errors
- Use `do-catch` with `print` for logging
- Use `guard let` with early returns
- Use `[weak self]` in closures to prevent retain cycles

```swift
// simple recoverable error
guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
    continue
}

// logged error
do {
    try SMAppService.mainApp.register()
} catch {
    print("Failed to update launch at login: \(error)")
}

// weak self in closures
DispatchQueue.global(qos: .userInitiated).async { [weak self] in
    // ...
    DispatchQueue.main.async {
        self?.allApps = apps
    }
}
```

### View Structure

```swift
struct ResultRowView: View {
    // @note properties first
    let result: SearchResult
    let isSelected: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // @note computed properties
    private var selectionColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.85, alpha: 1))
    }
    
    // @note body
    var body: some View {
        // view implementation
    }
}

#Preview {
    ResultRowView(result: SearchResult(...), isSelected: true)
}
```

### Enums

```swift
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
}
```

### Notifications

Define notification names as extensions:

```swift
extension Notification.Name {
    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")
    static let themeDidChange = Notification.Name("themeDidChange")
}
```

### Key Points

1. This is a menu bar app - no dock icon by default (uses `.accessory` activation policy)
2. Uses Carbon framework for global hotkey registration
3. Windows are borderless with custom `canBecomeKey` override
4. App sandbox enabled with user-selected file read access
5. Uses `NSViewRepresentable` for custom AppKit controls in SwiftUI
6. No external dependencies - pure Swift/SwiftUI

### Formatting

- Use 4-space indentation
- Opening brace on same line
- Prefer `private` for internal helpers
- Group related properties and methods together
