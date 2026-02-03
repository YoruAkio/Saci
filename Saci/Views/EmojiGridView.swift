//
//  EmojiGridView.swift
//  Saci
//

import SwiftUI

// @note emoji grid for library view
struct EmojiGridView: View {
    let emojis: [EmojiEntry]
    let copiedEmojiToken: String?
    let tokenPrefix: String
    var onSelect: (EmojiEntry) -> Void
    var columns: [GridItem]
    
    var body: some View {
        if emojis.isEmpty {
            Text("No emojis found")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.vertical, 24)
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(emojis, id: \.id) { entry in
                    EmojiCellView(
                        entry: entry,
                        isCopied: "\(tokenPrefix)|\(entry.id)" == copiedEmojiToken
                    )
                    .onTapGesture {
                        onSelect(entry)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

// @note emoji section header with count
struct EmojiSectionHeaderView: View {
    let title: String
    let count: Int
    @Environment(\.colorScheme) var colorScheme
    
    private var headerColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.4, alpha: 1))
            : Color(nsColor: NSColor(white: 0.5, alpha: 1))
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text("\(count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
            
            Spacer()
        }
        .foregroundColor(headerColor)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

// @note emoji grid cell view
private struct EmojiCellView: View {
    let entry: EmojiEntry
    let isCopied: Bool
    @State private var isHovered = false
    @Environment(\.colorScheme) var colorScheme
    
    private var hoverColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.22, alpha: 1))
            : Color(nsColor: NSColor(white: 0.9, alpha: 1))
    }

    private var copiedColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(calibratedRed: 0.12, green: 0.32, blue: 0.18, alpha: 1))
            : Color(nsColor: NSColor(calibratedRed: 0.72, green: 0.9, blue: 0.78, alpha: 1))
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(entry.emoji)
                .font(.system(size: 24))
            
            Text(isCopied ? "Copied" : entry.name)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 72, height: 56)
        .background(isCopied ? copiedColor : (isHovered ? hoverColor : Color.clear))
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
