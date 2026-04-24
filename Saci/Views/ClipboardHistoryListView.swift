//
//  ClipboardHistoryListView.swift
//  Saci
//

import SwiftUI

// @note performant clipboard history list with capped visible rows
struct ClipboardHistoryListView: View {
    let entries: [ClipboardEntry]
    @Binding var selectedIndex: Int
    var onSelect: (ClipboardEntry) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    private var selectionColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.85, alpha: 1))
    }
    
    var body: some View {
        if entries.isEmpty {
            Text("No clipboard history found")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.vertical, 24)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            clipboardRow(entry, index: index)
                                .id(index)
                                .onTapGesture {
                                    onSelect(entry)
                                }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
                }
                .onChange(of: selectedIndex) { index in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }
    
    // @note single clipboard row
    // @param entry clipboard entry to display
    // @param index visible list index
    private func clipboardRow(_ entry: ClipboardEntry, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.preview)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(relativeDate(entry.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("↵")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(index == selectedIndex ? selectionColor : Color.clear)
        .cornerRadius(6)
    }
    
    // @note compact relative timestamp for display
    // @param date clipboard creation date
    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
