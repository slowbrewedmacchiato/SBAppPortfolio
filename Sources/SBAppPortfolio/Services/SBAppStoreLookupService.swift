//  SBAppStoreLookupService.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Foundation

/// Fetches live App Store metadata for a studio catalog via the iTunes Lookup
/// API. Backed by a module-level shared in-memory cache
/// (``SBAppStoreLookupCache/shared``) with a one-hour TTL. Sends a single
/// batched request with comma-separated App Store IDs (the iTunes Lookup
/// endpoint accepts `?id=a,b,c&entity=software` and returns all results in
/// one response), so fetching five sibling apps is one HTTP call, not five.
///
/// The service itself is a lightweight struct that holds a `URLSession`
/// reference and the shared cache; it is safe to construct one per
/// ``SBAppPortfolioView`` because the cache survives view reinitialization
/// and sheet dismissal via ``SBAppStoreLookupCache/shared``.
public struct SBAppStoreLookupService: Sendable {
    private let urlSession: URLSession
    private let cache: SBAppStoreLookupCache

    /// Creates a lookup service bound to the shared module-level cache.
    /// The shared cache survives sheet dismissal, so the 1-hour TTL is
    /// effective across reopenings — not just within a single presentation.
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        self.cache = .shared
    }

    /// Internal initializer for tests that need an isolated cache so prior
    /// test runs cannot pollute the cache.
    internal init(urlSession: URLSession, cache: SBAppStoreLookupCache) {
        self.urlSession = urlSession
        self.cache = cache
    }

    /// Fetches metadata for every app in `configuration.visibleApps` (the
    /// studio catalog with `currentAppID` already excluded). Returns sorted
    /// alphabetically by `displayName`. Throws on network/HTTP/decoding
    /// failures; an empty lookup (no apps found) returns an empty array
    /// rather than an error so the sheet can show its empty state.
    public func fetchApps(
        for configuration: SBAppPortfolioConfiguration
    ) async throws -> [SBAppStoreApp] {
        let references = configuration.visibleApps
        guard !references.isEmpty else { return [] }

        let cacheKey = Self.cacheKey(for: references, country: configuration.lookupCountry)

        if let cached = await cache.cachedBatch(for: cacheKey) {
            return Self.sorted(cached)
        }

        let ids = references.map(\.appID).joined(separator: ",")
        var components = URLComponents(string: Self.iTunesLookupBase)
        components?.queryItems = [
            URLQueryItem(name: "id", value: ids),
            URLQueryItem(name: "country", value: configuration.lookupCountry),
            URLQueryItem(name: "entity", value: "software")
        ]

        guard let url = components?.url else {
            throw SBAppPortfolioError.invalidURL
        }

        do {
            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw SBAppPortfolioError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                throw SBAppPortfolioError.httpError(httpResponse.statusCode)
            }

            let decoded = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: data)
            let apps = decoded.results

            await cache.storeBatch(apps, for: cacheKey)
            return Self.sorted(apps)
        } catch is DecodingError {
            throw SBAppPortfolioError.decodingError
        } catch {
            if error is SBAppPortfolioError {
                throw error
            }
            if let urlError = error as? URLError, urlError.code == .cancelled {
                throw SBAppPortfolioError.requestCancelled
            }
            throw SBAppPortfolioError.networkError(error.localizedDescription)
        }
    }

    /// Clears the shared in-memory cache. Because the cache is module-level
    /// (``SBAppStoreLookupCache/shared``), this evicts every entry in the
    /// process, not just the caller's. That is the intended behavior for
    /// pull-to-refresh: the user is asking for fresh data, so the TTL window
    /// resets for all hosts sharing the process.
    public func clearCache() async {
        await cache.clear()
    }

    static let iTunesLookupBase = "https://itunes.apple.com/lookup"

    private static func sorted(_ apps: [SBAppStoreApp]) -> [SBAppStoreApp] {
        apps.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func cacheKey(for references: [SBAppReference], country: String) -> String {
        let ids = references.map(\.appID).sorted().joined(separator: ",")
        return "\(ids)|\(country)"
    }
}

/// Internal in-memory cache for a batched lookup result, isolated on an
/// actor. Keyed by the sorted set of app IDs plus the storefront country,
/// so a different `currentAppID` or `lookupCountry` produces a different
/// cache entry.
///
/// The default cache used by ``SBAppStoreLookupService`` is
/// ``SBAppStoreLookupCache/shared`` — a module-level `let` instance that
/// survives sheet dismissal, so the 1-hour TTL persists across reopenings
/// rather than being reset every time the host presents the sheet. Tests
/// construct isolated instances via `SBAppStoreLookupCache()` to avoid
/// polluting the shared cache.
internal actor SBAppStoreLookupCache {
    private struct Entry {
        let apps: [SBAppStoreApp]
        let fetchedAt: Date
    }

    private var storage: [String: Entry] = [:]
    private let ttl: TimeInterval = 3600

    /// Module-level shared cache. The reference is a `let`, so it is safe
    /// under Swift 6 concurrency; the actor isolates its internal state.
    static let shared = SBAppStoreLookupCache()

    func cachedBatch(for key: String) -> [SBAppStoreApp]? {
        guard let entry = storage[key], Date().timeIntervalSince(entry.fetchedAt) < ttl else {
            return nil
        }
        return entry.apps
    }

    func storeBatch(_ apps: [SBAppStoreApp], for key: String) {
        storage[key] = Entry(apps: apps, fetchedAt: Date())
    }

    func clear() {
        storage.removeAll()
    }
}
