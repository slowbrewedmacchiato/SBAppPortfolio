//  SBAppPortfolioConfiguration.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Foundation

/// Host-supplied configuration for the "More From Us" sheet.
///
/// Construct manually for a custom studio catalog, or use
/// ``SBAppPortfolioConfiguration/slowBrewed(currentAppID:lookupCountry:urlSession:)``
/// to pull in the package's built-in Slow Brewed catalog.
public struct SBAppPortfolioConfiguration: Sendable {
    /// The full studio catalog. The package filters out
    /// ``currentAppID`` at runtime, so the host does not need to maintain
    /// per-app omission lists.
    public let studioApps: [SBAppReference]

    /// App Store ID of the host app. Excluded from the displayed list.
    public let currentAppID: String

    /// Developer page URL rendered as the "View All Our Apps" footer row.
    public let developerPageURL: URL

    /// ISO country code passed to the iTunes Lookup `country` query parameter.
    /// Defaults to `"us"`. Hosts with strong non-US traction (e.g. an app
    /// popular in CN/JP) should pass the device storefront code so users see
    /// localized metadata and prices.
    public let lookupCountry: String

    /// URLSession used by the lookup service. Inject a custom session in
    /// tests; defaults to `.shared` in production.
    public let urlSession: URLSession

    public init(
        studioApps: [SBAppReference],
        currentAppID: String,
        developerPageURL: URL,
        lookupCountry: String = "us",
        urlSession: URLSession = .shared
    ) {
        self.studioApps = studioApps
        self.currentAppID = currentAppID
        self.developerPageURL = developerPageURL
        self.lookupCountry = lookupCountry
        self.urlSession = urlSession
    }

    /// Configuration backed by the package's built-in Slow Brewed catalog and
    /// developer page. Pass the host's own App Store ID as `currentAppID`
    /// so the host is excluded from the displayed rows.
    public static func slowBrewed(
        currentAppID: String,
        lookupCountry: String = "us",
        urlSession: URLSession = .shared
    ) -> SBAppPortfolioConfiguration {
        SBAppPortfolioConfiguration(
            studioApps: SBStudioApps.slowBrewed,
            currentAppID: currentAppID,
            developerPageURL: SBStudioApps.developerPageURL,
            lookupCountry: lookupCountry,
            urlSession: urlSession
        )
    }

    /// The catalog with the host app filtered out. Used by the lookup service
    /// and exposed for previews/tests.
    public var visibleApps: [SBAppReference] {
        studioApps.filter { $0.appID != currentAppID }
    }
}
