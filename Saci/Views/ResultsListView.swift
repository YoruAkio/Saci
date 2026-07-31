//
//  ResultsListView.swift
//  Saci
//

import SwiftUI

// @note scrollable, uncapped list of search results with lazy rendering
struct ResultsListView: View {
    let results: [SearchResult]
    @Binding var selectedIndex: Int
    var onSelect: (SearchResult) -> Void
    
    // @note bounded height for the visible area; anything beyond scrolls
    private var listHeight: CGFloat {
        LauncherLayout.resultsListHeight(count: results.count)
    }
    
    var body: some View {
        if !results.isEmpty {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: LauncherLayout.resultRowSpacing) {
                        // @note identity is the stable result id for both ForEach and .id() so
                        // @note rows never get matched by position and show stale content
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            ResultRowView(
                                result: result,
                                isSelected: index == selectedIndex,
                                index: index
                            )
                            .frame(height: LauncherLayout.resultRowHeight)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onSelect(result)
                            }
                            .id(result.id)
                        }
                    }
                    .padding(.vertical, LauncherLayout.resultListVerticalPadding)
                    .padding(.horizontal, 8)
                }
                .frame(height: listHeight)
                .onChange(of: selectedIndex) { index in
                    // @note keep the selected row visible during keyboard navigation
                    guard index >= 0, index < results.count else { return }
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(results[index].id, anchor: .center)
                    }
                }
            }
        }
    }
}
