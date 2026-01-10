//
//  ResultsListView.swift
//  Saci
//

import SwiftUI

// @note list of search results
struct ResultsListView: View {
    let results: [SearchResult]
    @Binding var selectedIndex: Int
    var onSelect: (SearchResult) -> Void
    var maxResults: Int
    
    var body: some View {
        if !results.isEmpty {
            VStack(spacing: 4) {
                ForEach(Array(results.prefix(maxResults).enumerated()), id: \.element.id) { index, result in
                    ResultRowView(
                        result: result,
                        isSelected: index == selectedIndex,
                        index: index
                    )
                    .onTapGesture {
                        onSelect(result)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
        }
    }
}
