//  CoreCompatibility.swift
//  SBAppPortfolio
//
//  Created by Angelo Cammalleri on 2026-08-21.

import SBAppPortfolioCore

// Explicit aliases preserve the original module's public source surface while
// allowing data-only consumers to depend on SBAppPortfolioCore directly.
public typealias SBAppReference = SBAppPortfolioCore.SBAppReference
public typealias SBAppStoreApp = SBAppPortfolioCore.SBAppStoreApp
public typealias SBAppPortfolioError = SBAppPortfolioCore.SBAppPortfolioError
public typealias SBAppStoreLookupService = SBAppPortfolioCore.SBAppStoreLookupService

public typealias SBAppLookupOrdering = SBAppPortfolioCore.SBAppLookupOrdering
public typealias SBAppLookupRequest = SBAppPortfolioCore.SBAppLookupRequest
public typealias SBAppLookupSource = SBAppPortfolioCore.SBAppLookupSource
public typealias SBAppLookupResult = SBAppPortfolioCore.SBAppLookupResult
public typealias SBAppLookupCachePolicy = SBAppPortfolioCore.SBAppLookupCachePolicy
public typealias SBAppStoreLookupClient = SBAppPortfolioCore.SBAppStoreLookupClient

public extension SBAppPortfolioCore.SBAppStoreLookupService {
    /// Compatibility path for the original presentation configuration.
    ///
    /// The Core API intentionally has no self-exclusion policy. This wrapper
    /// retains the original behavior by forwarding the already filtered IDs
    /// and alphabetizing the result for the existing sheet.
    func fetchApps(
        for configuration: SBAppPortfolioConfiguration
    ) async throws -> [SBAppPortfolioCore.SBAppStoreApp] {
        let request = SBAppPortfolioCore.SBAppLookupRequest(
            appIDs: configuration.visibleApps.map(\.appID),
            countryCode: configuration.lookupCountry,
            ordering: .displayName
        )
        return try await fetchApps(for: request).apps
    }
}
