//
//  EmojiEntry.swift
//  Saci
//

import Foundation

// @note emoji group keys for display
enum EmojiGroupKey: String, CaseIterable {
    case smileysPeople = "smileysPeople"
    case animalsNature = "animalsNature"
    case foodDrink = "foodDrink"
    case activity = "activity"
    case travelPlaces = "travelPlaces"
    case objects = "objects"
    case symbols = "symbols"
    case flags = "flags"
    
    var displayName: String {
        switch self {
        case .smileysPeople: return "Smileys & People"
        case .animalsNature: return "Animals & Nature"
        case .foodDrink: return "Food & Drink"
        case .activity: return "Activity"
        case .travelPlaces: return "Travel & Places"
        case .objects: return "Objects"
        case .symbols: return "Symbols"
        case .flags: return "Flags"
        }
    }
}

// @note emoji category kind
enum EmojiCategoryKind: String, Hashable {
    case all
    case frequent
    case group
    case subgroup
}

// @note model for emoji category
struct EmojiCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let kind: EmojiCategoryKind
    let groupKey: EmojiGroupKey?
    let subgroup: String?
    
    static let all = EmojiCategory(
        id: "all",
        title: "All",
        kind: .all,
        groupKey: nil,
        subgroup: nil
    )
    
    static let frequent = EmojiCategory(
        id: "frequent",
        title: "Frequently Used",
        kind: .frequent,
        groupKey: nil,
        subgroup: nil
    )
    
    static func group(_ key: EmojiGroupKey) -> EmojiCategory {
        EmojiCategory(
            id: "group-\(key.rawValue)",
            title: key.displayName,
            kind: .group,
            groupKey: key,
            subgroup: nil
        )
    }
    
    static func subgroup(_ name: String) -> EmojiCategory {
        EmojiCategory(
            id: "subgroup-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            title: name,
            kind: .subgroup,
            groupKey: nil,
            subgroup: name
        )
    }
}

// @note model for emoji entry
struct EmojiEntry: Identifiable, Hashable {
    let id: String
    let emoji: String
    let name: String
    let groupKey: EmojiGroupKey
    let subgroup: String
    let searchText: String
    
    init(emoji: String, name: String, groupKey: EmojiGroupKey, subgroup: String, searchText: String) {
        self.id = "\(emoji)-\(name)"
        self.emoji = emoji
        self.name = name
        self.groupKey = groupKey
        self.subgroup = subgroup
        self.searchText = searchText
    }
}
