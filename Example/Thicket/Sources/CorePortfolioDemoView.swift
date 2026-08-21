//  CorePortfolioDemoView.swift
//  Thicket
//
//  Created by Angelo Cammalleri on 2026-08-21.

import SBAppPortfolioCore
import SwiftUI

/// A deliberately host-owned portfolio surface.
///
/// Unlike the settings examples that present `SBAppPortfolioView`, this file
/// imports only the Core product. It keeps catalog order and fallback copy in
/// the host, then overlays live title, subtitle, artwork, price, genre, and
/// destination data by App Store ID.
struct CorePortfolioDemoView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL

    @State private var appsByID: [String: SBAppStoreApp] = [:]
    @State private var isLoading = false

    private let service = SBAppStoreLookupService()
    private let references = CorePortfolioDemoCatalog.apps

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: ThicketTheme.cardSpacing) {
                    Text(
                        String(
                            localized: "Host-owned UI using the Core API",
                            comment: "Section description above the Core-powered custom portfolio list."
                        )
                    )
                    .roundedFont(.footnote, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(items) { item in
                        appCard(item)
                    }
                }
                .padding(ThicketTheme.screenPadding)
            }
            .background(ThicketPalette.background(for: scheme))
            .navigationTitle(
                String(
                    localized: "Custom App List",
                    comment: "Navigation title for the Core-powered custom portfolio example."
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isLoading {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView()
                    }
                }
            }
            .task { await loadApps() }
            .refreshable {
                try? await service.invalidateCache(for: request)
                await loadApps()
            }
        }
        .tint(ThicketPalette.moss(for: scheme))
    }

    private var request: SBAppLookupRequest {
        SBAppLookupRequest(
            appIDs: references.map(\.appID),
            countryCode: Locale.current.region?.identifier ?? "us",
            ordering: .caller
        )
    }

    private var items: [CorePortfolioDemoItem] {
        references.map { reference in
            CorePortfolioDemoItem(
                reference: reference,
                storeApp: appsByID[reference.appID]
            )
        }
    }

    private func appCard(_ item: CorePortfolioDemoItem) -> some View {
        Button {
            if let appStoreURL = item.appStoreURL {
                openURL(appStoreURL)
            }
        } label: {
            ThicketCard {
                HStack(alignment: .top, spacing: ThicketTheme.rowSpacing) {
                    artwork(for: item)

                    VStack(alignment: .leading, spacing: ThicketTheme.copySpacing) {
                        Text(item.name)
                            .roundedFont(.headline, weight: .semibold)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)

                        Text(item.summary)
                            .roundedFont(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if let genre = item.genre {
                            Text(genre)
                                .roundedFont(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Spacer(minLength: ThicketTheme.minimumSpacer)

                    VStack(alignment: .trailing, spacing: ThicketTheme.copySpacing) {
                        if let price = item.price {
                            Text(price)
                                .roundedFont(.caption, weight: .bold)
                                .foregroundStyle(ThicketPalette.moss(for: scheme))
                        }

                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(ThicketTheme.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isLink)
    }

    private func artwork(for item: CorePortfolioDemoItem) -> some View {
        AsyncImage(url: item.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty, .failure:
                artworkPlaceholder
            @unknown default:
                artworkPlaceholder
            }
        }
        .frame(
            width: ThicketTheme.appIconSize,
            height: ThicketTheme.appIconSize
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: ThicketTheme.appIconCornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: ThicketTheme.appIconCornerRadius,
                style: .continuous
            )
            .stroke(
                ThicketPalette.hairline(for: scheme),
                lineWidth: ThicketTheme.hairlineWidth
            )
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(
            cornerRadius: ThicketTheme.appIconCornerRadius,
            style: .continuous
        )
        .fill(ThicketPalette.moss(for: scheme).opacity(ThicketTheme.placeholderOpacity))
        .overlay {
            Image(systemName: "square.grid.2x2.fill")
                .font(.title2)
                .foregroundStyle(ThicketPalette.moss(for: scheme))
        }
    }

    private func loadApps() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await service.fetchApps(for: request)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut) {
                appsByID = Dictionary(
                    uniqueKeysWithValues: result.apps.map { (String($0.trackId), $0) }
                )
            }
        } catch SBAppPortfolioError.requestCancelled {
            // The sheet left the hierarchy. Static fallback rows remain valid.
        } catch {
            // Network and storefront failures intentionally leave the complete
            // host-owned fallback list on screen.
        }
    }
}

private struct CorePortfolioDemoItem: Identifiable {
    let reference: SBAppReference
    let storeApp: SBAppStoreApp?

    var id: String { reference.appID }
    var name: String {
        storeApp?.trackCensoredName?.nonempty
            ?? storeApp?.trackName?.nonempty
            ?? reference.fallbackName
    }
    var summary: String {
        // Lookup responses frequently omit the actual App Store subtitle. The
        // host deliberately keeps its curated copy instead of substituting the
        // first sentence of a long store description.
        storeApp?.subtitle?.nonempty ?? reference.fallbackDescription
    }
    var artworkURL: URL? { storeApp?.bestArtworkURL }
    var appStoreURL: URL? {
        storeApp?.appStoreURL
            ?? URL(string: "https://apps.apple.com/app/id\(reference.appID)")
    }
    var genre: String? {
        storeApp?.primaryGenreName?.nonempty
            ?? storeApp?.genres?.first(where: { $0.nonempty != nil })
    }
    var price: String? {
        guard let storeApp else { return nil }
        return storeApp.isFree
            ? String(
                localized: "GET",
                comment: "Action label for a free app in the Core-powered custom portfolio example."
            )
            : storeApp.formattedPrice?.nonempty
    }
}

private enum CorePortfolioDemoCatalog {
    static let apps = [
        SBAppReference(
            appID: "6781631782",
            fallbackName: "AppStead",
            fallbackDescription: "App Store Connect workspace for indie developers."
        ),
        SBAppReference(
            appID: "6755578065",
            fallbackName: "CreatorCaps",
            fallbackDescription: "Caption videos quickly on your iPhone."
        ),
        SBAppReference(
            appID: "6751930050",
            fallbackName: "Glyppo",
            fallbackDescription: "Track glucose with clarity and calm design."
        )
    ]
}

private extension String {
    var nonempty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    CorePortfolioDemoView()
}
