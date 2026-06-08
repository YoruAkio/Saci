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
    
    // @note fixed row metrics so the visible height stays deterministic
    private let rowHeight: CGFloat = 40
    private let rowSpacing: CGFloat = 4
    private let verticalPadding: CGFloat = 8
    
    // @note max rows visible before the list scrolls (the list itself is uncapped)
    private let maxVisibleRows = 9
    
    // @note bounded height for the visible area; anything beyond scrolls
    private var listHeight: CGFloat {
        let visible = min(results.count, maxVisibleRows)
        guard visible > 0 else { return 0 }
        return CGFloat(visible) * rowHeight
            + CGFloat(visible - 1) * rowSpacing
            + verticalPadding * 2
    }
    
    var body: some View {
        if !results.isEmpty {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: rowSpacing) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            ResultRowView(
                                result: result,
                                isSelected: index == selectedIndex,
                                index: index
                            )
                            .equatable()
                            .frame(height: rowHeight)
                            .id(index)
                            .onTapGesture {
                                onSelect(result)
                            }
                        }
                    }
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, 8)
                }
                .frame(height: listHeight)
                .onChange(of: selectedIndex) { index in
                    // @note keep the selected row visible during keyboard navigation
                    guard index >= 0 else { return }
                    withAnimation(.easeInOut(duration: 0.12)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }
}
