//
//  ErrorManager.swift
//  Saci
//

import SwiftUI

// @note error types for the app
enum SaciError: Error, Identifiable {
    case appLaunchFailed(path: String, underlyingError: Error?)
    case cacheSaveFailed(underlyingError: Error?)
    case cacheLoadFailed(underlyingError: Error?)
    case hotkeyRegistrationFailed(code: Int32)
    case hotkeyHandlerFailed(code: Int32)
    
    var id: String {
        switch self {
        case .appLaunchFailed(let path, _):
            return "appLaunch_\(path)"
        case .cacheSaveFailed:
            return "cacheSave"
        case .cacheLoadFailed:
            return "cacheLoad"
        case .hotkeyRegistrationFailed(let code):
            return "hotkeyReg_\(code)"
        case .hotkeyHandlerFailed(let code):
            return "hotkeyHandler_\(code)"
        }
    }
    
    var title: String {
        switch self {
        case .appLaunchFailed:
            return "Failed to Launch Application"
        case .cacheSaveFailed:
            return "Failed to Save Cache"
        case .cacheLoadFailed:
            return "Failed to Load Cache"
        case .hotkeyRegistrationFailed:
            return "Failed to Register Hotkey"
        case .hotkeyHandlerFailed:
            return "Failed to Setup Hotkey Handler"
        }
    }
    
    var message: String {
        switch self {
        case .appLaunchFailed(let path, let error):
            var msg = "Could not launch application at:\n\(path)"
            if let error = error {
                msg += "\n\nError: \(error.localizedDescription)"
            }
            return msg
        case .cacheSaveFailed(let error):
            var msg = "Could not save app cache to disk."
            if let error = error {
                msg += "\n\nError: \(error.localizedDescription)"
            }
            return msg
        case .cacheLoadFailed(let error):
            var msg = "Could not load app cache from disk."
            if let error = error {
                msg += "\n\nError: \(error.localizedDescription)"
            }
            return msg
        case .hotkeyRegistrationFailed(let code):
            return "Could not register global hotkey.\n\nError code: \(code)\n\nThis may happen if another app is using the same hotkey. Try changing the hotkey in Settings."
        case .hotkeyHandlerFailed(let code):
            return "Could not setup hotkey event handler.\n\nError code: \(code)"
        }
    }
    
    var technicalDetails: String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var details = "Timestamp: \(timestamp)\n"
        details += "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        details += "Saci Version: 0.1.0-alpha\n\n"
        
        switch self {
        case .appLaunchFailed(let path, let error):
            details += "Error Type: App Launch Failed\n"
            details += "Path: \(path)\n"
            if let error = error {
                details += "Underlying Error: \(error)\n"
            }
        case .cacheSaveFailed(let error):
            details += "Error Type: Cache Save Failed\n"
            if let error = error {
                details += "Underlying Error: \(error)\n"
            }
        case .cacheLoadFailed(let error):
            details += "Error Type: Cache Load Failed\n"
            if let error = error {
                details += "Underlying Error: \(error)\n"
            }
        case .hotkeyRegistrationFailed(let code):
            details += "Error Type: Hotkey Registration Failed\n"
            details += "OSStatus Code: \(code)\n"
        case .hotkeyHandlerFailed(let code):
            details += "Error Type: Hotkey Handler Failed\n"
            details += "OSStatus Code: \(code)\n"
        }
        
        return details
    }
}

// @note manages error reporting and display
class ErrorManager: ObservableObject {
    static let shared = ErrorManager()
    
    @Published var currentError: SaciError?
    @Published var showErrorWindow = false
    
    private let githubRepoURL = "https://github.com/YoruAkio/Saci"
    
    private init() {}
    
    // @note report an error and optionally show window
    // @param error the error to report
    // @param showWindow whether to show the error window
    func report(_ error: SaciError, showWindow: Bool = true) {
        DispatchQueue.main.async {
            self.currentError = error
            if showWindow {
                self.showErrorWindow = true
            }
            // @note also log to console
            print("[Saci Error] \(error.title): \(error.message)")
        }
    }
    
    // @note open GitHub issues page with pre-filled bug report
    func openGitHubIssue() {
        guard let error = currentError else { return }
        
        let title = error.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = """
        ## Description
        \(error.message)
        
        ## Technical Details
        ```
        \(error.technicalDetails)
        ```
        
        ## Steps to Reproduce
        1. 
        2. 
        3. 
        
        ## Expected Behavior
        
        
        ## Additional Context
        
        """.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let urlString = "\(githubRepoURL)/issues/new?title=\(title)&body=\(body)&labels=bug"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // @note copy error details to clipboard
    func copyToClipboard() {
        guard let error = currentError else { return }
        
        let text = """
        \(error.title)
        
        \(error.message)
        
        Technical Details:
        \(error.technicalDetails)
        """
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
    
    // @note dismiss the error window
    func dismiss() {
        showErrorWindow = false
        currentError = nil
        // @note post notification to close the window
        NotificationCenter.default.post(name: .errorWindowShouldClose, object: nil)
    }
}

// @note notification name for error window close
extension Notification.Name {
    static let errorWindowShouldClose = Notification.Name("errorWindowShouldClose")
}
