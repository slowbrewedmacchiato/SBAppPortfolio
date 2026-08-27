//  SBAppPortfolioRowLoadingView.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import SwiftUI

/// Skeleton row shown while the lookup service is fetching metadata.
/// Shape and spacing match ``SBAppPortfolioRowView`` so the layout
/// does not shift when content arrives.
@available(iOS 18.0, macOS 13.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
struct SBAppPortfolioRowLoadingView: View {
    private let placeholderColor = Color.gray.opacity(0.2)

    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(placeholderColor)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(placeholderColor)
                    .frame(width: 140, height: 14)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(placeholderColor.opacity(0.7))
                    .frame(maxWidth: 220, minHeight: 12, maxHeight: 12, alignment: .leading)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(placeholderColor.opacity(0.7))
                    .frame(width: 90, height: 10)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .redacted(reason: .placeholder)
        .listRowBackground(Color.portfolioRowBackground)
    }
}
