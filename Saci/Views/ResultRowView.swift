//
//  ResultRowView.swift
//  Saci
//

import SwiftUI

// @note individual result item row with icon and name
struct ResultRowView: View, Equatable {
    let result: SearchResult
    let isSelected: Bool
    let index: Int
    
    // @note equatable to prevent unnecessary re-renders
    static func == (lhs: ResultRowView, rhs: ResultRowView) -> Bool {
        lhs.result.id == rhs.result.id && 
        lhs.isSelected == rhs.isSelected && 
        lhs.index == rhs.index
    }
    
    var body: some View {
        ResultRowContent(result: result, isSelected: isSelected, index: index)
    }
}

// @note inner content view with state for icon loading
private struct ResultRowContent: View {
    let result: SearchResult
    let isSelected: Bool
    let index: Int
    @Environment(\.colorScheme) var colorScheme
    
    // @note state for lazy-loaded icon
    @State private var icon: NSImage?
    @State private var currentPath: String = ""
    
    // @note selection background color based on theme
    private var selectionColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.85, alpha: 1))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // @note app icon (lazy loaded)
            iconView
            
            // @note app name with "Application" suffix
            HStack(spacing: 4) {
                Text(result.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Text("Application")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // @note keybind hint (⌘ + number)
            HStack(spacing: 2) {
                Text("⌘")
                    .font(.system(size: 11, weight: .medium))
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(.secondary)
            .frame(minWidth: 28, minHeight: 20)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? selectionColor : Color.clear)
        .cornerRadius(6)
        .onAppear {
            loadIconIfNeeded()
        }
        .onChange(of: result.path) { newPath in
            // @note reset icon when result changes
            if currentPath != newPath {
                icon = nil
                currentPath = newPath
                loadIconIfNeeded()
            }
        }
    }
    
    // @note icon view with placeholder
    @ViewBuilder
    private var iconView: some View {
        if let loadedIcon = icon {
            Image(nsImage: loadedIcon)
                .resizable()
                .frame(width: 24, height: 24)
        } else {
            // @note placeholder while loading
            Image(systemName: "app.fill")
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundColor(.secondary)
        }
    }
    
    // @note load icon lazily via IconCacheService
    private func loadIconIfNeeded() {
        let path = result.path
        currentPath = path
        
        // @note try to get cached icon first (synchronous)
        if let cached = IconCacheService.shared.getCachedIcon(for: path) {
            icon = cached
            return
        }
        
        // @note load async
        IconCacheService.shared.loadIcon(for: path) { [path] loadedIcon in
            // @note only set if path hasn't changed
            if currentPath == path {
                icon = loadedIcon
            }
        }
    }
}
