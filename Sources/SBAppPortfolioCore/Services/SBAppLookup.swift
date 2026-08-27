//  SBAppLookup.swift
//  SBAppPortfolioCore
//
//  Created by Angelo Cammalleri on 2026-08-21.

import Foundation

/// Ordering applied after the service filters a response to requested IDs.
public enum SBAppLookupOrdering: String, Codable, Sendable, Hashable {
    /// Preserve the caller's first-occurrence input order.
    case caller
    /// Sort by the resolved display name.
    case displayName
    /// Preserve the order returned by Apple or stored in the cache entry.
    case response

    /// A spelling alias for ``caller``.
    public static var input: Self { .caller }
}

/// A raw App Store lookup independent of portfolio presentation policy.
public struct SBAppLookupRequest: Codable, Sendable, Hashable {
    public let appIDs: [String]
    public let countryCode: String
    public let ordering: SBAppLookupOrdering

    public init(
        appIDs: [String],
        countryCode: String = "us",
        ordering: SBAppLookupOrdering = .caller
    ) {
        self.appIDs = appIDs
        self.countryCode = countryCode
        self.ordering = ordering
    }
}

/// Where the result's metadata originated.
public enum SBAppLookupSource: String, Codable, Sendable, Hashable {
    case network
    case freshCache
    case staleCache
}

/// Metadata returned for a request plus IDs Apple did not return.
public struct SBAppLookupResult: Sendable, Equatable {
    public let apps: [SBAppStoreApp]
    public let missingAppIDs: [String]
    public let source: SBAppLookupSource
    public let countryCode: String

    public init(
        apps: [SBAppStoreApp],
        missingAppIDs: [String],
        source: SBAppLookupSource,
        countryCode: String
    ) {
        self.apps = apps
        self.missingAppIDs = missingAppIDs
        self.source = source
        self.countryCode = countryCode
    }

    public func app(forAppID appID: String) -> SBAppStoreApp? {
        apps.first { String($0.trackId) == appID }
    }
}

/// Controls decoded metadata caching independently from URLSession caching.
public struct SBAppLookupCachePolicy: Sendable, Equatable {
    public let timeToLive: TimeInterval
    public let allowsStaleDataOnError: Bool

    public init(
        timeToLive: TimeInterval = 3600,
        allowsStaleDataOnError: Bool = true
    ) {
        self.timeToLive = max(0, timeToLive)
        self.allowsStaleDataOnError = allowsStaleDataOnError
    }

    public static let standard = SBAppLookupCachePolicy()
    public static let disabled = SBAppLookupCachePolicy(
        timeToLive: 0,
        allowsStaleDataOnError: false
    )

    var usesCache: Bool {
        timeToLive > 0 || allowsStaleDataOnError
    }
}

/// Injectable lookup contract for host-owned presentation and tests.
public protocol SBAppStoreLookupClient: Sendable {
    func fetchApps(for request: SBAppLookupRequest) async throws -> SBAppLookupResult
    func invalidateCache(for request: SBAppLookupRequest) async throws
    func clearCache() async
}
