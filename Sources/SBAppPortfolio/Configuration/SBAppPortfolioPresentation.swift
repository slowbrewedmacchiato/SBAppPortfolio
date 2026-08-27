//  SBAppPortfolioPresentation.swift
//  SBAppPortfolio
//
//  Created by Angelo Cammalleri on 2026-08-21.

import Foundation

/// Presentation policy for ``SBAppPortfolioView``.
///
/// The default value preserves the original 1.0 sheet. Hosts that already own
/// navigation or want a smaller portfolio surface can selectively hide the
/// package chrome without replacing the package's data layer.
public struct SBAppPortfolioPresentation: Sendable, Equatable {
    public enum CurrentAppBehavior: String, Sendable, Hashable {
        /// Hide the app that is presenting the portfolio.
        case exclude
        /// Keep the current app in the portfolio.
        case include
    }

    public enum Ordering: String, Sendable, Hashable {
        /// Preserve the order supplied in the studio catalog.
        case catalog
        /// Sort by the resolved App Store or fallback name.
        case alphabetical
    }

    public enum SummaryPolicy: String, Sendable, Hashable {
        /// Use Apple's subtitle, then a short description-derived summary,
        /// then the host's fallback copy. This preserves the original sheet.
        case appStoreSubtitleThenDescription
        /// Use Apple's subtitle when it exists, otherwise retain the host's
        /// curated fallback. This is useful when product copy is intentional.
        case appStoreSubtitleThenFallback
        /// Always retain the host's fallback description.
        case fallbackOnly
    }

    public var currentAppBehavior: CurrentAppBehavior
    public var ordering: Ordering
    public var summaryPolicy: SummaryPolicy
    public var showsDoneButton: Bool
    public var showsDeveloperLink: Bool
    public var showsPrice: Bool
    public var showsGenre: Bool
    public var navigationTitle: String?
    public var sectionTitle: String?
    public var sectionFooter: String?

    public init(
        currentAppBehavior: CurrentAppBehavior = .exclude,
        ordering: Ordering = .alphabetical,
        summaryPolicy: SummaryPolicy = .appStoreSubtitleThenDescription,
        showsDoneButton: Bool = true,
        showsDeveloperLink: Bool = true,
        showsPrice: Bool = true,
        showsGenre: Bool = true,
        navigationTitle: String? = nil,
        sectionTitle: String? = nil,
        sectionFooter: String? = nil
    ) {
        self.currentAppBehavior = currentAppBehavior
        self.ordering = ordering
        self.summaryPolicy = summaryPolicy
        self.showsDoneButton = showsDoneButton
        self.showsDeveloperLink = showsDeveloperLink
        self.showsPrice = showsPrice
        self.showsGenre = showsGenre
        self.navigationTitle = navigationTitle
        self.sectionTitle = sectionTitle
        self.sectionFooter = sectionFooter
    }

    public static let standard = SBAppPortfolioPresentation()
}

/// A presentation-ready app built from a static reference and optional live
/// App Store metadata.
///
/// Fallback copy is never discarded. This lets package-owned and host-owned
/// UI render a complete row when a storefront omits an app or the device is
/// offline.
public struct SBAppPortfolioItem: Identifiable, Sendable, Equatable {
    public let reference: SBAppReference
    public let storeApp: SBAppStoreApp?
    public let name: String
    public let summary: String
    public let appStoreURL: URL?
    public let artworkURL: URL?
    public let genre: String?
    public let formattedPrice: String?
    public let isFree: Bool

    public var id: String { reference.appID }
    public var hasLiveMetadata: Bool { storeApp != nil }

    public init(
        reference: SBAppReference,
        storeApp: SBAppStoreApp? = nil,
        summaryPolicy: SBAppPortfolioPresentation.SummaryPolicy = .appStoreSubtitleThenDescription
    ) {
        self.reference = reference
        self.storeApp = storeApp
        self.name = storeApp?.portfolioName ?? reference.fallbackName
        self.summary = Self.summary(
            reference: reference,
            storeApp: storeApp,
            policy: summaryPolicy
        )
        self.appStoreURL = storeApp?.appStoreURL
            ?? URL(string: "https://apps.apple.com/app/id\(reference.appID)")
        self.artworkURL = storeApp?.bestArtworkURL
        self.genre = storeApp?.portfolioGenre
        self.formattedPrice = storeApp?.formattedPrice
        self.isFree = storeApp?.isFree ?? true
    }

    private static func summary(
        reference: SBAppReference,
        storeApp: SBAppStoreApp?,
        policy: SBAppPortfolioPresentation.SummaryPolicy
    ) -> String {
        switch policy {
        case .appStoreSubtitleThenDescription:
            return storeApp?.portfolioSubtitle
                ?? storeApp?.portfolioDescriptionSummary
                ?? reference.fallbackDescription
        case .appStoreSubtitleThenFallback:
            return storeApp?.portfolioSubtitle ?? reference.fallbackDescription
        case .fallbackOnly:
            return reference.fallbackDescription
        }
    }
}

private extension SBAppStoreApp {
    var portfolioName: String? {
        trackCensoredName?.portfolioNonempty ?? trackName?.portfolioNonempty
    }

    var portfolioSubtitle: String? {
        subtitle?.portfolioNonempty
    }

    var portfolioGenre: String? {
        primaryGenreName?.portfolioNonempty
            ?? genres?.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }

    var portfolioDescriptionSummary: String? {
        guard let description = description?.portfolioNonempty else { return nil }
        let firstSentence = description.components(separatedBy: ". ").first ?? description
        if firstSentence.count <= 120 { return firstSentence }
        if description.count <= 120 { return description }
        return String(description.prefix(117)) + "..."
    }
}

private extension String {
    var portfolioNonempty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
