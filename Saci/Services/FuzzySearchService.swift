//
//  FuzzySearchService.swift
//  Saci
//

import Foundation

// @note fuzzy search service for matching queries against app names
// implements scoring-based fuzzy matching with letter subsequence matching
struct FuzzySearchService {
    
    // @note match result with score for ranking
    struct FuzzyMatch {
        let result: SearchResult
        let score: Int
    }
    
    // @note perform fuzzy search on apps array
    // @param query search query string
    // @param apps array of SearchResult to search
    // @param limit maximum results to return
    // @return sorted array of SearchResult by match score
    static func search(query: String, in apps: [SearchResult], limit: Int) -> [SearchResult] {
        let queryLower = query.lowercased()
        
        // @note skip empty query
        guard !queryLower.isEmpty else { return [] }
        
        var matches: [FuzzyMatch] = []
        
        for app in apps {
            if let score = calculateScore(query: queryLower, target: app.name) {
                matches.append(FuzzyMatch(result: app, score: score))
            }
        }
        
        // @note sort by score descending and take top results
        matches.sort { $0.score > $1.score }
        
        return Array(matches.prefix(limit).map { $0.result })
    }
    
    // @note calculate fuzzy match score between query and target
    // @param query lowercased search query
    // @param target app name to match against
    // @return score (higher is better) or nil if no match
    private static func calculateScore(query: String, target: String) -> Int? {
        let targetLower = target.lowercased()
        
        // @note exact match - highest score
        if targetLower == query {
            return 10000
        }
        
        // @note prefix match - very high score
        if targetLower.hasPrefix(query) {
            return 9000 + (100 - min(target.count, 100))
        }
        
        // @note word start match (query matches start of any word)
        if let wordScore = wordStartScore(query: query, target: targetLower) {
            return 8000 + wordScore
        }
        
        // @note contains match - high score
        if targetLower.contains(query) {
            return 7000 + (100 - min(target.count, 100))
        }
        
        // @note abbreviation match (vscode -> Visual Studio Code)
        if let abbrevScore = abbreviationScore(query: query, originalTarget: target) {
            return 6000 + abbrevScore
        }
        
        // @note subsequence match - all query chars appear in order
        if let subseqScore = subsequenceScore(query: query, target: targetLower) {
            return subseqScore
        }
        
        return nil
    }
    
    // @note check if query matches start of any word in target
    // @param query search query
    // @param target lowercased target string
    // @return score or nil
    private static func wordStartScore(query: String, target: String) -> Int? {
        let words = target.split { $0 == " " || $0 == "-" || $0 == "_" || $0 == "." }
        
        for (index, word) in words.enumerated() {
            if word.hasPrefix(query) {
                // @note earlier word = higher score
                return 100 - (index * 10)
            }
        }
        
        return nil
    }
    
    // @note calculate abbreviation match score
    // matches first letters of words: vsc -> Visual Studio Code
    // @param query search query
    // @param originalTarget original case target for word detection
    // @return score or nil if no match
    private static func abbreviationScore(query: String, originalTarget: String) -> Int? {
        // @note extract first letters of words and capitals
        var initials: [Character] = []
        var prevWasLower = false
        var prevWasSeparator = true
        
        for char in originalTarget {
            let isSeparator = char == " " || char == "-" || char == "_" || char == "."
            
            if isSeparator {
                prevWasSeparator = true
                prevWasLower = false
                continue
            }
            
            let isCapital = char.isUppercase
            
            // @note include: char after separator, or capital after lowercase (camelCase)
            if prevWasSeparator || (isCapital && prevWasLower) {
                initials.append(Character(char.lowercased()))
            }
            
            prevWasLower = char.isLowercase
            prevWasSeparator = false
        }
        
        let abbreviation = String(initials)
        
        // @note query must match initials exactly or as prefix
        if abbreviation == query {
            return 200
        }
        
        if abbreviation.hasPrefix(query) {
            return 150
        }
        
        // @note check if query chars appear in order in abbreviation
        if matchesSubsequence(query: query, target: abbreviation) {
            return 100
        }
        
        return nil
    }
    
    // @note check if all query chars appear in order in target
    // @param query search query
    // @param target target string
    // @return true if subsequence match
    private static func matchesSubsequence(query: String, target: String) -> Bool {
        var targetIter = target.makeIterator()
        
        for queryChar in query {
            var found = false
            while let targetChar = targetIter.next() {
                if targetChar == queryChar {
                    found = true
                    break
                }
            }
            if !found { return false }
        }
        
        return true
    }
    
    // @note calculate subsequence match score
    // all query chars must appear in order in target
    // scoring: consecutive matches, word boundary matches, early position
    // @param query search query
    // @param target lowercased target string
    // @return score based on match quality or nil if no match
    private static func subsequenceScore(query: String, target: String) -> Int? {
        let queryChars = Array(query)
        let targetChars = Array(target)
        
        guard !queryChars.isEmpty && !targetChars.isEmpty else { return nil }
        
        // @note find best match positions using greedy with scoring
        var matchPositions: [Int] = []
        var targetIdx = 0
        
        for queryChar in queryChars {
            var found = false
            while targetIdx < targetChars.count {
                if targetChars[targetIdx] == queryChar {
                    matchPositions.append(targetIdx)
                    targetIdx += 1
                    found = true
                    break
                }
                targetIdx += 1
            }
            if !found { return nil }
        }
        
        // @note calculate score based on match quality
        var score = 0
        
        // @note base score for matching
        score += queryChars.count * 10
        
        // @note bonus for consecutive matches
        for i in 1..<matchPositions.count {
            if matchPositions[i] == matchPositions[i-1] + 1 {
                score += 15
            }
        }
        
        // @note bonus for matching at word boundaries
        for pos in matchPositions {
            if pos == 0 {
                score += 20
            } else {
                let prevChar = targetChars[pos - 1]
                if prevChar == " " || prevChar == "-" || prevChar == "_" || prevChar == "." {
                    score += 15
                } else if targetChars[pos].isUppercase {
                    score += 10
                }
            }
        }
        
        // @note bonus for early first match
        let firstMatchPos = matchPositions[0]
        score += max(0, 20 - firstMatchPos)
        
        // @note penalty for large gaps between matches
        for i in 1..<matchPositions.count {
            let gap = matchPositions[i] - matchPositions[i-1] - 1
            if gap > 3 {
                score -= gap
            }
        }
        
        // @note penalty for long targets (prefer shorter names)
        score -= target.count / 5
        
        return max(1, score)
    }
}
