//
//  ClipboardHistoryListView.swift
//  Saci
//

import SwiftUI

// @note ordered actions shown in the clipboard actions box
enum ClipboardAction: Int, CaseIterable {
    case paste
    case copy
    case pin
    case share
    case delete
    case clearAll
    
    func title(isPinned: Bool) -> String {
        switch self {
        case .paste: return "Paste to Finder"
        case .copy: return "Copy to Clipboard"
        case .pin: return isPinned ? "Unpin" : "Pin"
        case .share: return "Share..."
        case .delete: return "Delete Entry"
        case .clearAll: return "Clear All History..."
        }
    }
    
    var icon: String {
        switch self {
        case .paste: return "return"
        case .copy: return "doc.on.doc"
        case .pin: return "pin"
        case .share: return "square.and.arrow.up"
        case .delete: return "trash"
        case .clearAll: return "trash"
        }
    }
    
    var key: String {
        switch self {
        case .paste: return ""
        case .copy: return "⌘C"
        case .pin: return "⌘P"
        case .share: return ""
        case .delete: return "⌃X"
        case .clearAll: return "⌘⇧⌫"
        }
    }
    
    var isDestructive: Bool {
        self == .delete || self == .clearAll
    }
    
    // @note divider shown above this action in the box
    var hasDividerBefore: Bool {
        self == .delete
    }
}

// @note master-detail clipboard history UI (list on the left, preview + info on the right)
struct ClipboardHistoryView: View {
    @ObservedObject var service: ClipboardHistoryService
    let entries: [ClipboardEntry]
    @Binding var selectedIndex: Int
    @Binding var showActions: Bool
    @Binding var actionIndex: Int
    
    // @note run an action against the currently selected entry
    var onRunAction: (ClipboardAction) -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    private var selectionColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.22, alpha: 1))
            : Color(nsColor: NSColor(white: 0.86, alpha: 1))
    }
    
    private var dividerColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.25, alpha: 1))
            : Color(nsColor: NSColor(white: 0.82, alpha: 1))
    }
    
    private var actionsBoxColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.17, alpha: 1))
            : Color(nsColor: NSColor(white: 0.99, alpha: 1))
    }
    
    private var actionHighlightColor: Color {
        colorScheme == .dark
            ? Color(nsColor: NSColor(white: 0.30, alpha: 1))
            : Color(nsColor: NSColor(calibratedRed: 0.78, green: 0.93, blue: 0.97, alpha: 1))
    }
    
    // @note currently detailed entry
    private var selectedEntry: ClipboardEntry? {
        guard selectedIndex >= 0, selectedIndex < entries.count else { return nil }
        return entries[selectedIndex]
    }
    
    private var pinnedEntries: [(index: Int, entry: ClipboardEntry)] {
        entries.enumerated().filter { $0.element.isPinned }.map { ($0.offset, $0.element) }
    }
    
    private var recentEntries: [(index: Int, entry: ClipboardEntry)] {
        entries.enumerated().filter { !$0.element.isPinned }.map { ($0.offset, $0.element) }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                if entries.isEmpty {
                    emptyState
                } else {
                    HStack(spacing: 0) {
                        listColumn
                            .frame(width: 272)
                        
                        Rectangle()
                            .fill(dividerColor)
                            .frame(width: 1)
                        
                        detailColumn
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxHeight: .infinity)
                }
                
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
                
                footer
            }
            
            if showActions {
                actionsBox
                    .padding(.trailing, 12)
                    .padding(.bottom, 42)
            }
        }
    }
    
    // @note empty placeholder
    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No clipboard history found")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - List
    
    private var listColumn: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if !pinnedEntries.isEmpty {
                        sectionHeader("Pinned")
                        ForEach(pinnedEntries, id: \.entry.id) { item in
                            row(item.entry, index: item.index)
                        }
                    }
                    if !recentEntries.isEmpty {
                        sectionHeader("Today")
                        ForEach(recentEntries, id: \.entry.id) { item in
                            row(item.entry, index: item.index)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .onChange(of: selectedIndex) { index in
                guard index >= 0, index < entries.count else { return }
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(entries[index].id, anchor: .center)
                }
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func row(_ entry: ClipboardEntry, index: Int) -> some View {
        HStack(spacing: 10) {
            thumbnail(entry)
            
            Text(rowTitle(entry))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 4)
            
            if entry.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(45))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(index == selectedIndex ? selectionColor : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedIndex = index
        }
        .id(entry.id)
    }
    
    @ViewBuilder
    private func thumbnail(_ entry: ClipboardEntry) -> some View {
        if entry.type == .image, let image = service.image(for: entry) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else {
            Image(systemName: entry.type.iconName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(iconTint(entry.type))
                .frame(width: 32, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(iconTint(entry.type).opacity(0.18))
                )
        }
    }
    
    private func iconTint(_ type: ClipboardItemType) -> Color {
        switch type {
        case .text: return .secondary
        case .url: return .purple
        case .image: return .blue
        }
    }
    
    private func rowTitle(_ entry: ClipboardEntry) -> String {
        switch entry.type {
        case .image: return "Image"
        default: return entry.preview
        }
    }
    
    // MARK: - Detail
    
    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let entry = selectedEntry {
                preview(entry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(16)
                
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
                
                information(entry)
                    .padding(16)
            } else {
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func preview(_ entry: ClipboardEntry) -> some View {
        switch entry.type {
        case .image:
            if let image = service.image(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Image unavailable")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        case .url:
            ScrollView {
                Text(entry.content)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.blue)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .text:
            ScrollView {
                Text(entry.content)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func information(_ entry: ClipboardEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Information")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            infoRow(label: "Source") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text(entry.sourceApp ?? "Unknown")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            infoRow(label: "Type") {
                HStack(spacing: 6) {
                    Image(systemName: entry.type.iconName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(entry.type.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            if entry.type != .image {
                infoRow(label: "Characters") {
                    Text("\(entry.characterCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
                infoRow(label: "Words") {
                    Text("\(entry.wordCount)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            
            infoRow(label: "Copied") {
                Text(Self.relativeFormatter.localizedString(for: entry.createdAt, relativeTo: Date()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }
    
    private func infoRow<Content: View>(label: String, @ViewBuilder value: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            value()
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack(spacing: 16) {
            Spacer()
            
            footerHint(label: "Copy to Clipboard", key: "↵") {
                onRunAction(.copy)
            }
            
            Button(action: { showActions.toggle() }) {
                HStack(spacing: 6) {
                    Text("Actions")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("⌘ K")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(minWidth: 28, minHeight: 18)
                        .padding(.horizontal, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.secondary.opacity(0.15))
                        )
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
    
    private func footerHint(label: String, key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(key)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(minWidth: 20, minHeight: 18)
                    .padding(.horizontal, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                    )
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions box
    
    private var actionsBox: some View {
        let isPinned = selectedEntry?.isPinned ?? false
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(ClipboardAction.allCases.enumerated()), id: \.element) { idx, action in
                if action.hasDividerBefore {
                    Divider().padding(.vertical, 4)
                }
                actionRow(action, isSelected: idx == actionIndex, isPinned: isPinned)
            }
        }
        .padding(6)
        .frame(width: 270)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(actionsBoxColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(dividerColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 6)
    }
    
    private func actionRow(_ action: ClipboardAction, isSelected: Bool, isPinned: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: action.icon)
                .font(.system(size: 12))
                .frame(width: 18)
                .foregroundColor(action.isDestructive ? .red : .primary)
            Text(action.title(isPinned: isPinned))
                .font(.system(size: 13))
                .foregroundColor(action.isDestructive ? .red : .primary)
            Spacer()
            if !action.key.isEmpty {
                Text(action.key)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? actionHighlightColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onRunAction(action)
        }
    }
    
    // @note shared formatter reused across renders (creation is expensive)
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
