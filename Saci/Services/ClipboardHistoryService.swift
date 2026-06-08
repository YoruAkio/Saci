//
//  ClipboardHistoryService.swift
//  Saci
//

import AppKit
import Combine

// @note service for monitoring and searching clipboard history (text, links, images)
class ClipboardHistoryService: ObservableObject {
    static let shared = ClipboardHistoryService()
    
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var results: [ClipboardEntry] = []
    // @note active type filter (nil => all types)
    @Published var typeFilter: ClipboardItemType?
    
    private let pasteboard = NSPasteboard.general
    private let stateQueue = DispatchQueue(label: "com.saci.clipboardHistoryState")
    private let searchQueue = DispatchQueue(label: "com.saci.clipboardHistorySearch", qos: .userInitiated)
    private let cacheFileName = "clipboard_history.json"
    private var timer: Timer?
    private var lastChangeCount: Int
    private var isRestoringEntry = false
    private var persistWorkItem: DispatchWorkItem?
    private var searchWorkItem: DispatchWorkItem?
    private var lastQuery: String = ""
    
    private var saciDirURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let saciDir = appSupport.appendingPathComponent("Saci", isDirectory: true)
        if !FileManager.default.fileExists(atPath: saciDir.path) {
            try? FileManager.default.createDirectory(at: saciDir, withIntermediateDirectories: true)
        }
        return saciDir
    }
    
    private var cacheFileURL: URL? {
        saciDirURL?.appendingPathComponent(cacheFileName)
    }
    
    // @note directory holding persisted clipboard images
    private var imagesDirURL: URL? {
        guard let dir = saciDirURL?.appendingPathComponent("clipboard_images", isDirectory: true) else {
            return nil
        }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    private init() {
        lastChangeCount = pasteboard.changeCount
        loadFromCache()
    }
    
    // @note begin lightweight clipboard polling
    func startMonitoring() {
        guard timer == nil else { return }
        let newTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        // @note allow the system to coalesce wakeups for better energy efficiency
        // @note (polling must stay on so copies made in other apps are still captured)
        newTimer.tolerance = 0.2
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }
    
    // @note stop clipboard polling
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        persistWorkItem?.cancel()
        persistNow()
    }
    
    // @note load the persisted image for an image entry
    // @param entry clipboard entry
    // @return NSImage if available
    func image(for entry: ClipboardEntry) -> NSImage? {
        guard entry.type == .image,
              let fileName = entry.imageFileName,
              let url = imagesDirURL?.appendingPathComponent(fileName),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }
    
    // @note search history (filtered by query + type), pinned entries first
    // @param query search text
    // @param limit maximum displayed results
    func search(query: String, limit: Int = 200) {
        lastQuery = query
        searchWorkItem?.cancel()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let snapshot = entries
        let filterType = typeFilter
        
        let workItem = DispatchWorkItem {
            let matched = snapshot.filter { entry -> Bool in
                if let filterType = filterType, entry.type != filterType { return false }
                if normalized.isEmpty { return true }
                return entry.searchableContent.contains(normalized)
            }
            // @note pinned first, preserving recency order within each group
            let pinned = matched.filter { $0.isPinned }
            let others = matched.filter { !$0.isPinned }
            let filtered = Array((pinned + others).prefix(limit))
            DispatchQueue.main.async { [weak self] in
                self?.results = filtered
            }
        }
        searchWorkItem = workItem
        searchQueue.asyncAfter(deadline: .now() + .milliseconds(60), execute: workItem)
    }
    
    // @note re-run the current search (after pin/delete/filter changes)
    func refreshResults() {
        search(query: lastQuery)
    }
    
    // @note copy an entry back to the clipboard and move it to top
    // @param entry clipboard entry to restore
    func restore(_ entry: ClipboardEntry) {
        isRestoringEntry = true
        pasteboard.clearContents()
        if entry.type == .image, let image = image(for: entry), let tiff = image.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        } else {
            pasteboard.setString(entry.content, forType: .string)
        }
        lastChangeCount = pasteboard.changeCount
        isRestoringEntry = false
        
        var updatedEntries = entries
        if let index = updatedEntries.firstIndex(where: { $0.id == entry.id }) {
            var updated = updatedEntries.remove(at: index)
            updated.lastUsedAt = Date()
            updated.useCount += 1
            // @note keep pinned entries grouped at the front; others go to top of non-pinned
            let insertIndex = updated.isPinned ? 0 : updatedEntries.firstIndex(where: { !$0.isPinned }) ?? updatedEntries.count
            updatedEntries.insert(updated, at: insertIndex)
            entries = updatedEntries
            schedulePersist()
            refreshResults()
        }
    }
    
    // @note toggle the pinned state of an entry
    // @param entry clipboard entry to pin/unpin
    func togglePin(_ entry: ClipboardEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].isPinned.toggle()
        schedulePersist()
        refreshResults()
    }
    
    // @note delete a single entry (and its image file if any)
    // @param entry clipboard entry to delete
    func delete(_ entry: ClipboardEntry) {
        if let fileName = entry.imageFileName {
            deleteImageFile(fileName)
        }
        entries.removeAll { $0.id == entry.id }
        schedulePersist()
        refreshResults()
    }
    
    // @note clear all clipboard history entries and image files
    func clearHistory() {
        for entry in entries {
            if let fileName = entry.imageFileName { deleteImageFile(fileName) }
        }
        entries = []
        results = []
        persistNow()
    }
    
    // @note set the active type filter and refresh results
    // @param type type to filter by, or nil for all
    func setTypeFilter(_ type: ClipboardItemType?) {
        typeFilter = type
        refreshResults()
    }
    
    // @note clear visible search results only
    func clearResults() {
        results = []
    }
    
    // @note apply current user limit to loaded history
    func enforceLimit() {
        let limit = AppSettings.shared.normalizedClipboardHistoryLimit
        if entries.count > limit {
            entries = Array(entries.prefix(limit))
            schedulePersist()
        }
    }
    
    // @note check pasteboard only when change count moves
    private func checkClipboard() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        guard !isRestoringEntry else { return }
        
        let sourceApp = NSWorkspace.shared.frontmostApplication?.localizedName
        
        // @note prefer image data when present (and no plain string)
        if pasteboard.string(forType: .string) == nil,
           let imageData = imageDataFromPasteboard() {
            addImageContent(imageData, sourceApp: sourceApp)
            return
        }
        
        guard let string = pasteboard.string(forType: .string) else { return }
        addTextContent(string, sourceApp: sourceApp)
    }
    
    // @note read png/tiff image data from the pasteboard if available
    private func imageDataFromPasteboard() -> Data? {
        if let png = pasteboard.data(forType: .png) { return png }
        if let tiff = pasteboard.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        return nil
    }
    
    // @note add a text/url clipboard item, preventing duplicates and oversized storage
    // @param content copied text content
    // @param sourceApp frontmost app name at copy time
    private func addTextContent(_ content: String, sourceApp: String?) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let type: ClipboardItemType = ClipboardHistoryService.isURL(trimmed) ? .url : .text
        
        var updatedEntries = entries
        if let duplicateIndex = updatedEntries.firstIndex(where: { $0.content == content && $0.type != .image }) {
            var existing = updatedEntries.remove(at: duplicateIndex)
            existing.lastUsedAt = Date()
            existing.useCount += 1
            let insertIndex = existing.isPinned ? 0 : updatedEntries.firstIndex(where: { !$0.isPinned }) ?? updatedEntries.count
            updatedEntries.insert(existing, at: insertIndex)
        } else {
            let entry = ClipboardEntry(content: content, type: type, sourceApp: sourceApp)
            let insertIndex = updatedEntries.firstIndex(where: { !$0.isPinned }) ?? updatedEntries.count
            updatedEntries.insert(entry, at: insertIndex)
        }
        
        commit(updatedEntries)
    }
    
    // @note add an image clipboard item, saving its data to disk
    // @param data png image data
    // @param sourceApp frontmost app name at copy time
    private func addImageContent(_ data: Data, sourceApp: String?) {
        guard let imagesDir = imagesDirURL else { return }
        let fileName = "\(UUID().uuidString).png"
        let fileURL = imagesDir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
        } catch {
            return
        }
        
        let entry = ClipboardEntry(
            content: "",
            type: .image,
            sourceApp: sourceApp,
            imageFileName: fileName
        )
        var updatedEntries = entries
        let insertIndex = updatedEntries.firstIndex(where: { !$0.isPinned }) ?? updatedEntries.count
        updatedEntries.insert(entry, at: insertIndex)
        commit(updatedEntries)
    }
    
    // @note enforce the size limit then publish + persist a new entries snapshot
    // @param updatedEntries new entries array
    private func commit(_ updatedEntries: [ClipboardEntry]) {
        var snapshot = updatedEntries
        let limit = AppSettings.shared.normalizedClipboardHistoryLimit
        if snapshot.count > limit {
            // @note evict overflow but never evict pinned entries
            let overflow = snapshot[limit...]
            for entry in overflow where !entry.isPinned {
                if let fileName = entry.imageFileName { deleteImageFile(fileName) }
            }
            let pinnedOverflow = snapshot[limit...].filter { $0.isPinned }
            snapshot = Array(snapshot.prefix(limit)) + pinnedOverflow
        }
        entries = snapshot
        schedulePersist()
        refreshResults()
    }
    
    // @note remove a persisted image file
    private func deleteImageFile(_ fileName: String) {
        guard let url = imagesDirURL?.appendingPathComponent(fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    // @note detect whether a string is a web url
    static func isURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(" "), !trimmed.contains("\n") else { return false }
        let lower = trimmed.lowercased()
        guard lower.hasPrefix("http://") || lower.hasPrefix("https://") else { return false }
        return URL(string: trimmed) != nil
    }
    
    // @note load persisted history from disk
    private func loadFromCache() {
        guard let cacheURL = cacheFileURL,
              FileManager.default.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data) else {
            return
        }
        let limit = AppSettings.shared.normalizedClipboardHistoryLimit
        entries = Array(decoded.prefix(limit))
    }
    
    // @note debounce disk writes to avoid writing on every copy
    private func schedulePersist() {
        persistWorkItem?.cancel()
        let snapshot = entries
        let workItem = DispatchWorkItem { [weak self] in
            self?.writeEntries(snapshot)
        }
        persistWorkItem = workItem
        stateQueue.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    // @note write current history immediately
    private func persistNow() {
        writeEntries(entries)
    }
    
    // @note persist entries to cache file
    // @param entries entries snapshot
    private func writeEntries(_ entries: [ClipboardEntry]) {
        guard let cacheURL = cacheFileURL,
              let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: cacheURL)
    }
}
