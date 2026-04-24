//
//  ClipboardHistoryService.swift
//  Saci
//

import AppKit
import Combine

// @note service for monitoring and searching clipboard text history
class ClipboardHistoryService: ObservableObject {
    static let shared = ClipboardHistoryService()
    
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var results: [ClipboardEntry] = []
    
    private let pasteboard = NSPasteboard.general
    private let stateQueue = DispatchQueue(label: "com.saci.clipboardHistoryState")
    private let searchQueue = DispatchQueue(label: "com.saci.clipboardHistorySearch", qos: .userInitiated)
    private let cacheFileName = "clipboard_history.json"
    private var timer: Timer?
    private var lastChangeCount: Int
    private var isRestoringEntry = false
    private var persistWorkItem: DispatchWorkItem?
    private var searchWorkItem: DispatchWorkItem?
    
    private var cacheFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let saciDir = appSupport.appendingPathComponent("Saci", isDirectory: true)
        if !FileManager.default.fileExists(atPath: saciDir.path) {
            try? FileManager.default.createDirectory(at: saciDir, withIntermediateDirectories: true)
        }
        return saciDir.appendingPathComponent(cacheFileName)
    }
    
    private init() {
        lastChangeCount = pasteboard.changeCount
        loadFromCache()
    }
    
    // @note begin lightweight clipboard polling
    func startMonitoring() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
    
    // @note stop clipboard polling
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        persistWorkItem?.cancel()
        persistNow()
    }
    
    // @note search history using precomputed lowercase content
    // @param query search text
    // @param limit maximum displayed results
    func search(query: String, limit: Int = 80) {
        searchWorkItem?.cancel()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let snapshot = entries
        
        let workItem = DispatchWorkItem {
            let filtered: [ClipboardEntry]
            if normalized.isEmpty {
                filtered = Array(snapshot.prefix(limit))
            } else {
                filtered = Array(snapshot.lazy.filter { $0.searchableContent.contains(normalized) }.prefix(limit))
            }
            DispatchQueue.main.async { [weak self] in
                self?.results = filtered
            }
        }
        searchWorkItem = workItem
        searchQueue.asyncAfter(deadline: .now() + .milliseconds(60), execute: workItem)
    }
    
    // @note copy a history entry back to the clipboard and move it to top
    // @param entry clipboard entry to restore
    func restore(_ entry: ClipboardEntry) {
        isRestoringEntry = true
        pasteboard.clearContents()
        pasteboard.setString(entry.content, forType: .string)
        lastChangeCount = pasteboard.changeCount
        isRestoringEntry = false
        
        var updatedEntries = entries
        if let index = updatedEntries.firstIndex(where: { $0.id == entry.id }) {
            var updated = updatedEntries.remove(at: index)
            updated.lastUsedAt = Date()
            updated.useCount += 1
            updatedEntries.insert(updated, at: 0)
            entries = updatedEntries
            schedulePersist()
        }
    }
    
    // @note clear all clipboard history entries
    func clearHistory() {
        entries = []
        results = []
        persistNow()
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
        guard let string = pasteboard.string(forType: .string) else { return }
        addClipboardContent(string)
    }
    
    // @note add a text clipboard item while preventing duplicates and oversized storage
    // @param content copied text content
    private func addClipboardContent(_ content: String) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        var updatedEntries = entries
        if updatedEntries.first?.content == content { return }
        if let duplicateIndex = updatedEntries.firstIndex(where: { $0.content == content }) {
            var existing = updatedEntries.remove(at: duplicateIndex)
            existing.lastUsedAt = Date()
            existing.useCount += 1
            updatedEntries.insert(existing, at: 0)
        } else {
            updatedEntries.insert(ClipboardEntry(content: content), at: 0)
        }
        
        let limit = AppSettings.shared.normalizedClipboardHistoryLimit
        if updatedEntries.count > limit {
            updatedEntries.removeSubrange(limit..<updatedEntries.count)
        }
        
        entries = updatedEntries
        schedulePersist()
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
