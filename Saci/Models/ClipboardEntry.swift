//
//  ClipboardEntry.swift
//  Saci
//

import Foundation

// @note clipboard history item with precomputed search text
struct ClipboardEntry: Identifiable, Codable, Hashable {
    let id: String
    let content: String
    let preview: String
    let searchableContent: String
    let createdAt: Date
    var lastUsedAt: Date
    var useCount: Int
    
    init(content: String, createdAt: Date = Date(), lastUsedAt: Date = Date(), useCount: Int = 0) {
        self.id = UUID().uuidString
        self.content = content
        self.preview = ClipboardEntry.makePreview(from: content)
        self.searchableContent = content.lowercased()
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }
    
    // @note restore cached fields when decoding older encoded values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try container.decode(Date.self, forKey: .lastUsedAt)
        useCount = try container.decode(Int.self, forKey: .useCount)
        preview = (try? container.decode(String.self, forKey: .preview)) ?? ClipboardEntry.makePreview(from: content)
        searchableContent = (try? container.decode(String.self, forKey: .searchableContent)) ?? content.lowercased()
    }
    
    // @note compact single-line preview for list display
    // @param content raw clipboard text
    private static func makePreview(from content: String) -> String {
        let normalized = content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.count <= 160 { return normalized }
        return String(normalized.prefix(160))
    }
}
