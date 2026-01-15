//
//  SearchBarView.swift
//  Saci
//

import SwiftUI

// @note search input with magnifying glass icon
struct SearchBarView: View {
    @Binding var searchText: String
    var onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(.gray)
            
            TextField("Search...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 24, weight: .light))
                .foregroundColor(.white)
                .onSubmit(onSubmit)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(nsColor: NSColor(white: 0.15, alpha: 1)))
    }
}
