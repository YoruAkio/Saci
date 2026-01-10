//
//  ResultRowView.swift
//  Saci
//

import SwiftUI

// @note individual result item row with icon and name
struct ResultRowView: View {
    let result: SearchResult
    let isSelected: Bool
    let index: Int
    @Environment(\.colorScheme) var colorScheme
    
    // @note selection background color based on theme
    private var selectionColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.85, alpha: 1))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon = result.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(result.path)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
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
    }
}
