//
//  EmojiLibraryService.swift
//  Saci
//

import Foundation
import SwiftUI

// @note service to load and search emoji data
class EmojiLibraryService: ObservableObject {
    static let shared = EmojiLibraryService()
    
    @Published private(set) var emojis: [EmojiEntry] = []
    @Published private(set) var categories: [EmojiCategory] = [.all, .frequent]
    @Published private(set) var groupedEmojis: [EmojiGroupKey: [EmojiEntry]] = [:]
    @Published private(set) var subgroupedEmojis: [String: [EmojiEntry]] = [:]
    @Published private(set) var subgroupOrder: [String] = []
    @Published private(set) var emojiLookup: [String: EmojiEntry] = [:]
    
    @AppStorage("emojiUsage") private var emojiUsageRaw: String = ""
    
    private let buildQueue = DispatchQueue(label: "com.saci.emojiBuild", qos: .userInitiated)
    private let searchQueue = DispatchQueue(label: "com.saci.emojiSearch", qos: .userInitiated)
    private let stateQueue = DispatchQueue(label: "com.saci.emojiState")
    
    private var emojiCache: [EmojiEntry] = []
    private var usageCache: [String: EmojiUsage] = [:]
    private var isBuilding = false
    private var usageLoaded = false
    private var buildWorkItem: DispatchWorkItem?
    private var searchWorkItem: DispatchWorkItem?
    
    private init() {}
    
    // @note lazy load emoji list
    func loadIfNeeded() {
        let shouldStart = stateQueue.sync { () -> Bool in
            if isBuilding || !emojiCache.isEmpty {
                return false
            }
            isBuilding = true
            return true
        }
        
        guard shouldStart else { return }
        
        buildWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let built = self.buildEmojiData()
            
            DispatchQueue.main.async {
                self.emojis = built.entries
                self.groupedEmojis = built.grouped
                self.subgroupedEmojis = built.subgroups
                self.subgroupOrder = built.subgroupOrder
                self.emojiLookup = built.lookup
                self.categories = built.categories
                
                self.stateQueue.sync {
                    self.emojiCache = built.entries
                    self.isBuilding = false
                }
            }
        }
        buildWorkItem = workItem
        buildQueue.async(execute: workItem)
    }
    
    // @note search emojis by name or keyword
    // @param query search text
    // @param entries source entries to search
    // @param completion returns filtered emojis on main thread
    func search(query: String, in entries: [EmojiEntry], completion: @escaping ([EmojiEntry]) -> Void) {
        loadIfNeeded()
        
        searchWorkItem?.cancel()
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        let workItem = DispatchWorkItem {
            let filtered: [EmojiEntry]
            if normalized.isEmpty {
                filtered = entries
            } else {
                filtered = entries.filter { entry in
                    entry.searchText.contains(normalized) || entry.emoji.contains(normalized)
                }
            }
            
            DispatchQueue.main.async {
                completion(filtered)
            }
        }
        
        searchWorkItem = workItem
        searchQueue.asyncAfter(deadline: .now() + .milliseconds(60), execute: workItem)
    }
    
    // @note record emoji usage for frequent list
    // @param emoji emoji character to record
    func recordUsage(_ emoji: String) {
        loadUsageIfNeeded()
        
        var usage = usageCache[emoji] ?? EmojiUsage(emoji: emoji, count: 0, lastUsed: Date())
        usage.count += 1
        usage.lastUsed = Date()
        usageCache[emoji] = usage
        persistUsage()
    }
    
    // @note get frequently used emoji entries
    // @param limit maximum entries to return
    func frequentEntries(limit: Int) -> [EmojiEntry] {
        loadIfNeeded()
        loadUsageIfNeeded()
        guard !emojiLookup.isEmpty else { return [] }
        
        let sorted = usageCache.values.sorted {
            if $0.count != $1.count {
                return $0.count > $1.count
            }
            return $0.lastUsed > $1.lastUsed
        }
        
        var results: [EmojiEntry] = []
        results.reserveCapacity(limit)
        
        for usage in sorted {
            if let entry = emojiLookup[usage.emoji] {
                results.append(entry)
            }
            if results.count >= limit { break }
        }
        
        return results
    }
    
    // @note build emoji list from unicode emoji-test.txt
    private func buildEmojiData() -> EmojiBuildResult {
        let url = Bundle.main.url(
            forResource: "emoji-test",
            withExtension: "txt",
            subdirectory: "Emoji"
        ) ?? Bundle.main.url(
            forResource: "emoji-test",
            withExtension: "txt"
        )
        
        guard let resolvedURL = url else {
            return EmojiBuildResult.empty
        }
        
        guard let content = try? String(contentsOf: resolvedURL, encoding: .utf8) else {
            return EmojiBuildResult.empty
        }
        
        var entries: [EmojiEntry] = []
        entries.reserveCapacity(4000)
        
        var lookup: [String: EmojiEntry] = [:]
        var grouped: [EmojiGroupKey: [EmojiEntry]] = [:]
        var subgroups: [String: [EmojiEntry]] = [:]
        var subgroupOrder: [String] = []
        
        var currentGroup: EmojiGroupKey?
        var currentSubgroup: String = ""
        
        for rawLine in content.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            
            if line.hasPrefix("# group:") {
                let groupName = line.replacingOccurrences(of: "# group:", with: "").trimmingCharacters(in: .whitespaces)
                currentGroup = mapGroupKey(groupName)
                continue
            }
            
            if line.hasPrefix("# subgroup:") {
                let subgroupName = line.replacingOccurrences(of: "# subgroup:", with: "").trimmingCharacters(in: .whitespaces)
                currentSubgroup = formatSubgroupName(subgroupName)
                continue
            }
            
            if line.isEmpty || line.hasPrefix("#") { continue }
            guard let groupKey = currentGroup else { continue }
            
            guard let hashRange = line.range(of: " # ") else { continue }
            
            let left = String(line[..<hashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let right = String(line[hashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            let leftParts = left.components(separatedBy: ";")
            if leftParts.count < 2 { continue }
            
            let status = leftParts[1].trimmingCharacters(in: .whitespaces)
            if status != "fully-qualified" { continue }
            
            let rightParts = right.split(separator: " ")
            guard let emoji = rightParts.first.map(String.init) else { continue }
            
            var nameStartIndex = 1
            if rightParts.count > 1 && rightParts[1].hasPrefix("E") {
                nameStartIndex = 2
            }
            
            let rawName: String
            if rightParts.count > nameStartIndex {
                rawName = rightParts[nameStartIndex...].joined(separator: " ")
            } else {
                rawName = "emoji"
            }
            let displayName = formatDisplayName(rawName)
            
            let searchText = [
                rawName.lowercased(),
                displayName.lowercased(),
                groupKey.displayName.lowercased(),
                currentSubgroup.lowercased()
            ]
            .joined(separator: " ")
            
            let entry = EmojiEntry(
                emoji: emoji,
                name: displayName,
                groupKey: groupKey,
                subgroup: currentSubgroup,
                searchText: searchText
            )
            
            entries.append(entry)
            
            if lookup[emoji] == nil {
                lookup[emoji] = entry
            }
            
            grouped[groupKey, default: []].append(entry)
            
            if !currentSubgroup.isEmpty {
                if subgroups[currentSubgroup] == nil {
                    subgroupOrder.append(currentSubgroup)
                }
                subgroups[currentSubgroup, default: []].append(entry)
            }
        }
        
        var categories: [EmojiCategory] = [.all, .frequent]
        for key in EmojiGroupKey.allCases {
            if let entries = grouped[key], !entries.isEmpty {
                categories.append(.group(key))
            }
        }
        return EmojiBuildResult(
            entries: entries,
            grouped: grouped,
            subgroups: subgroups,
            subgroupOrder: subgroupOrder,
            lookup: lookup,
            categories: categories
        )
    }
    
    // @note map unicode group name to display group
    private func mapGroupKey(_ groupName: String) -> EmojiGroupKey? {
        switch groupName {
        case "Smileys & Emotion", "People & Body":
            return .smileysPeople
        case "Animals & Nature":
            return .animalsNature
        case "Food & Drink":
            return .foodDrink
        case "Activities":
            return .activity
        case "Travel & Places":
            return .travelPlaces
        case "Objects":
            return .objects
        case "Symbols":
            return .symbols
        case "Flags":
            return .flags
        default:
            return nil
        }
    }
    
    // @note format subgroup name to title case
    private func formatSubgroupName(_ name: String) -> String {
        if name == "other-symbol" {
            return "Other Symbols"
        }
        if name == "other-object" {
            return "Other Objects"
        }
        
        return name.replacingOccurrences(of: "-", with: " ")
            .lowercased()
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
    
    // @note format display name to title case
    private func formatDisplayName(_ name: String) -> String {
        name.lowercased()
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
    
    // @note load usage cache
    private func loadUsageIfNeeded() {
        guard !usageLoaded else { return }
        usageLoaded = true
        
        if emojiUsageRaw.isEmpty {
            usageCache = [:]
            return
        }
        
        guard let data = emojiUsageRaw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([EmojiUsage].self, from: data) else {
            usageCache = [:]
            return
        }
        
        var map: [String: EmojiUsage] = [:]
        for item in decoded {
            map[item.emoji] = item
        }
        usageCache = map
    }
    
    // @note persist usage cache
    private func persistUsage() {
        let values = Array(usageCache.values)
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else { return }
        emojiUsageRaw = string
    }
}

// @note emoji build result container
private struct EmojiBuildResult {
    let entries: [EmojiEntry]
    let grouped: [EmojiGroupKey: [EmojiEntry]]
    let subgroups: [String: [EmojiEntry]]
    let subgroupOrder: [String]
    let lookup: [String: EmojiEntry]
    let categories: [EmojiCategory]
    
    static let empty = EmojiBuildResult(
        entries: [],
        grouped: [:],
        subgroups: [:],
        subgroupOrder: [],
        lookup: [:],
        categories: [.all, .frequent]
    )
}

// @note usage model for frequent emojis
private struct EmojiUsage: Codable {
    let emoji: String
    var count: Int
    var lastUsed: Date
}
