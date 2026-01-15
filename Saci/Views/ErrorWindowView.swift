//
//  ErrorWindowView.swift
//  Saci
//

import SwiftUI

// @note error window view for displaying errors with GitHub report option
struct ErrorWindowView: View {
    @ObservedObject var errorManager = ErrorManager.shared
    @State private var showDetails = false
    @Environment(\.colorScheme) var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.15, alpha: 1))
            : Color(nsColor: NSColor(white: 0.98, alpha: 1))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // @note header with icon and title
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(errorManager.currentError?.title ?? "Error")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("An error occurred in Saci")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(20)
            
            Divider()
            
            // @note error message
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(errorManager.currentError?.message ?? "Unknown error")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // @note expandable technical details
                    if let error = errorManager.currentError {
                        DisclosureGroup(isExpanded: $showDetails) {
                            Text(error.technicalDetails)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                        } label: {
                            Text("Technical Details")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: 200)
            
            Divider()
            
            // @note action buttons
            HStack(spacing: 12) {
                Button(action: { errorManager.copyToClipboard() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: { errorManager.dismiss() }) {
                    Text("Dismiss")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.escape)
                
                Button(action: { errorManager.openGitHubIssue() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.bubble")
                            .font(.system(size: 11))
                        Text("Report Issue")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding(16)
        }
        .frame(width: 450, height: 280)
        .background(backgroundColor)
    }
}

#Preview {
    ErrorWindowView()
}
