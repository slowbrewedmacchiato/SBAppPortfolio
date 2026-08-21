//  SBAppPortfolioRowView.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import SwiftUI

/// A single app row for package-owned or host-owned portfolio UI.
///
/// The row renders resolved fallback/live metadata from
/// ``SBAppPortfolioItem``. By default it opens the App Store destination from
/// the environment; pass `onOpen` when a host owns routing or analytics.
@available(iOS 18.0, macOS 13.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public struct SBAppPortfolioRowView: View {
    private let item: SBAppPortfolioItem
    private let showsPrice: Bool
    private let showsGenre: Bool
    private let onOpen: (() -> Void)?
    @Environment(\.openURL) private var openURL

    public init(
        item: SBAppPortfolioItem,
        showsPrice: Bool = true,
        showsGenre: Bool = true,
        onOpen: (() -> Void)? = nil
    ) {
        self.item = item
        self.showsPrice = showsPrice
        self.showsGenre = showsGenre
        self.onOpen = onOpen
    }

    public var body: some View {
        Button {
            if let onOpen {
                onOpen()
            } else if let url = item.appStoreURL {
                openURL(url)
            }
        } label: {
            HStack(spacing: 16) {
                AsyncImage(url: item.artworkURL) { phase in
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
                        Text(item.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)

                        Spacer(minLength: 8)

                        // Matches the App Store's own action pill: a filled
                        // neutral capsule with bold tinted text. Using `.tint`
                        // keeps the package theme-neutral, the pill adopts
                        // whatever accent the host applies to the sheet.
                        if showsPrice {
                            SBAppPortfolioActionPill(title: actionTitle)
                        }
                    }

                    Text(item.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    if showsGenre, let genre = item.genre {
                        Text(genre)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.portfolioRowBackground)
        .accessibilityLabel(
            Text(
                String(
                    localized: "Open \(item.name) on the App Store",
                    bundle: .module,
                    comment: "Accessibility label for a portfolio app row."
                )
            )
        )
    }

    private var actionTitle: String {
        if item.isFree {
            return String(
                localized: "GET",
                bundle: .module,
                comment: "Portfolio row action label for free apps."
            )
        }
        return item.formattedPrice
            ?? String(
                localized: "Free",
                bundle: .module,
                comment: "Fallback price label when App Store lookup omits formatted price."
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
