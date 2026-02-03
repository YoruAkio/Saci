//
//  SearchResult.swift
//  Saci
//

import SwiftUI

// @note result kind for launcher items
enum SearchResultKind: String, Hashable {
    case app
    case command
}

// @note model for search result item
struct SearchResult: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let kind: SearchResultKind
    let subtitle: String
    let iconSystemName: String?
    
    init(
        name: String,
        path: String,
        kind: SearchResultKind = .app,
        subtitle: String = "Application",
        iconSystemName: String? = nil
    ) {
        self.id = path
        self.name = name
        self.path = path
        self.kind = kind
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
        lhs.id == rhs.id
    }
    
    static func emojiLibraryCommand() -> SearchResult {
        SearchResult(
            name: "Emoji Library",
            path: "command://emoji-library",
            kind: .command,
            subtitle: "Command",
            iconSystemName: "face.smiling"
        )
    }
}

// @note cached app entry for persistent storage
struct CachedApp: Codable {
    let name: String
    let path: String
    let modificationDate: Date
    
    // @note convert to SearchResult (icon loaded separately via IconCacheService)
    func toSearchResult() -> SearchResult {
        return SearchResult(name: name, path: path)
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
