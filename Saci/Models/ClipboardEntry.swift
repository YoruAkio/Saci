//
//  ClipboardEntry.swift
//  Saci
//

import Foundation

// @note kind of clipboard content
enum ClipboardItemType: String, Codable {
    case text
    case url
    case image
    
    // @note label shown in the information panel and list
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .url: return "Link"
        case .image: return "Image"
        }
    }
    
    // @note sf symbol used for the row/type icon
    var iconName: String {
        switch self {
        case .text: return "doc.text"
        case .url: return "link"
        case .image: return "photo"
        }
    }
}

// @note clipboard history item with precomputed search text and metadata
struct ClipboardEntry: Identifiable, Codable, Hashable {
    let id: String
    let content: String
    let preview: String
    let searchableContent: String
    let type: ClipboardItemType
    // @note display name of the app the content was copied from (nil => Unknown)
    let sourceApp: String?
    // @note file name (within the images dir) when type == .image
    let imageFileName: String?
    var isPinned: Bool
    let createdAt: Date
    var lastUsedAt: Date
    var useCount: Int
    
    // @note number of characters in the text content
    var characterCount: Int {
        content.count
    }
    
    // @note number of whitespace-separated words in the text content
    var wordCount: Int {
        content.split { $0 == " " || $0.isNewline || $0 == "\t" }.count
    }
    
    init(
        content: String,
        type: ClipboardItemType = .text,
        sourceApp: String? = nil,
        imageFileName: String? = nil,
        isPinned: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        useCount: Int = 0
    ) {
        self.id = UUID().uuidString
        self.content = content
        self.type = type
        self.sourceApp = sourceApp
        self.imageFileName = imageFileName
        self.isPinned = isPinned
        self.preview = ClipboardEntry.makePreview(from: content, type: type)
        self.searchableContent = (content + " " + (sourceApp ?? "") + " " + type.displayName).lowercased()
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.useCount = useCount
    }
    
    // @note restore cached/new fields when decoding older encoded values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUsedAt = try container.decode(Date.self, forKey: .lastUsedAt)
        useCount = try container.decode(Int.self, forKey: .useCount)
        type = (try? container.decode(ClipboardItemType.self, forKey: .type)) ?? .text
        sourceApp = try? container.decodeIfPresent(String.self, forKey: .sourceApp)
        imageFileName = try? container.decodeIfPresent(String.self, forKey: .imageFileName)
        isPinned = (try? container.decode(Bool.self, forKey: .isPinned)) ?? false
        let decodedType = type
        preview = (try? container.decode(String.self, forKey: .preview)) ?? ClipboardEntry.makePreview(from: content, type: decodedType)
        searchableContent = (try? container.decode(String.self, forKey: .searchableContent)) ?? content.lowercased()
    }
    
    // @note compact single-line preview for list display
    // @param content raw clipboard text
    // @param type content kind
    private static func makePreview(from content: String, type: ClipboardItemType) -> String {
        if type == .image {
            return "Image"
        }
        let normalized = content
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.count <= 200 { return normalized }
        return String(normalized.prefix(200))
    }
}
