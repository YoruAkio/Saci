//
//  SearchResult.swift
//  Saci
//

import SwiftUI

// @note model for app search result item
struct SearchResult: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    var icon: NSImage?
    
    init(name: String, path: String, icon: NSImage? = nil) {
        self.id = path
        self.name = name
        self.path = path
        self.icon = icon
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
}

// @note cached app entry for persistent storage
struct CachedApp: Codable {
    let name: String
    let path: String
    let modificationDate: Date
    
    // @note convert to SearchResult with icon loaded
    func toSearchResult() -> SearchResult {
        let icon = NSWorkspace.shared.icon(forFile: path)
        return SearchResult(name: name, path: path, icon: icon)
    }
}

// @note app cache container
struct AppCache: Codable {
    var apps: [CachedApp]
    var lastUpdated: Date
    
    init(apps: [CachedApp] = [], lastUpdated: Date = Date()) {
        self.apps = apps
        self.lastUpdated = lastUpdated
    }
}
