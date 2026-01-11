<h1 align="center">Saci</h1>

<p align="center">
  A powerful macOS productivity launcher that provides Spotlight-like functionality built using native Swift/SwiftUI, inspired by Alfred and Raycast.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-alpha-orange" alt="Status: Alpha">
  <img src="https://img.shields.io/badge/platform-macOS-blue" alt="Platform: macOS">
  <img src="https://img.shields.io/badge/swift-5.0-orange" alt="Swift 5.0">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License: MIT">
</p>

## Features

- **Quick App Launching** - Search and launch applications instantly with a global hotkey
- **Global Hotkey** - Trigger from anywhere with customizable shortcuts (Option+Space, Cmd+Space, or Ctrl+Space)
- **Native Performance** - Built with pure Swift/SwiftUI, no external dependencies
- **Menu Bar App** - Lives in your menu bar, always ready when you need it
- **Customizable Appearance** - Light, dark, or system theme with optional transparency effects
- **Keyboard Navigation** - Full keyboard support with arrow keys and Enter to launch

## Requirements

- macOS 13.7 or later
- Xcode 15.2 (for building from source)

> **Note**: This app was built and tested on macOS 13.7 using Xcode 15.2.

## Installation

### Build from Source

```bash
git clone https://github.com/YoruAkio/Saci.git
cd Saci
xcodebuild -project Saci.xcodeproj -scheme Saci -configuration Release build
```

The built app will be in the `build/` directory.

> **Note**: The pre-build app it's not ready for distribution yet. You can build it from source if you want to try it out.

## Basic Usage

1. Press **Option + Space** (default) to open Saci
2. Type to search for applications
3. Use **Arrow Keys** to navigate results
4. Press **Enter** to launch the selected app
5. Press **Escape** to close

## Contributing

Contributions are welcome! Feel free to submit pull requests or open issues.

If you find a bug, please consider opening an issue with:
- A clear description of the problem
- Steps to reproduce
- Your macOS version and Xcode version

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
