//  SBAppPortfolioRowView.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import SwiftUI

/// A single app row in the "More From Us" sheet. Renders the live artwork
/// and metadata from ``SBAppStoreApp``; tapping opens the App Store URL
/// via the environment's `openURL`.
struct SBAppPortfolioRowView: View {
    let app: SBAppStoreApp
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let url = app.appStoreURL {
                openURL(url)
            }
        } label: {
            HStack(spacing: 16) {
                AsyncImage(url: app.artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderIcon
                    case .empty:
                        placeholderIcon
                    @unknown default:
                        placeholderIcon
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.portfolioHairline, lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(app.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer(minLength: 8)

                        Text(app.isFree
                            ? String(localized: "GET", bundle: .module, comment: "Portfolio row action label for free apps.")
                            : app.displayPrice)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Capsule().stroke(Color.portfolioHairline, lineWidth: 1))
                    }

                    Text(app.displaySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(app.primaryGenre)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.portfolioRowBackground)
        .accessibilityLabel(
            Text(
                String(
                    localized: "Open \(app.displayName) on the App Store",
                    bundle: .module,
                    comment: "Accessibility label for a portfolio app row."
                )
            )
        )
    }

    private var placeholderIcon: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.gray.opacity(0.15))
            .overlay {
                Image(systemName: "apps.iphone")
                    .foregroundStyle(.secondary)
            }
    }
}
