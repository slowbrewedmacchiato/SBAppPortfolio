//  SBAppStoreLookupService.swift
//  SBAppPortfolioCore
//
//  Created by Angelo Cammalleri on 2026-08-21.

import Foundation

/// Fetches live App Store metadata with a batched iTunes Lookup request.
public struct SBAppStoreLookupService: SBAppStoreLookupClient, Sendable {
    private let urlSession: URLSession
    private let cache: SBAppStoreLookupCache
    private let cachePolicy: SBAppLookupCachePolicy
    private let now: @Sendable () -> Date

    public init(
        urlSession: URLSession = .shared,
        cachePolicy: SBAppLookupCachePolicy = .standard
    ) {
        self.urlSession = urlSession
        self.cache = urlSession === URLSession.shared
            ? .shared
            : SBAppStoreLookupCache()
        self.cachePolicy = cachePolicy
        self.now = { Date() }
    }

    init(
        urlSession: URLSession,
        cache: SBAppStoreLookupCache,
        cachePolicy: SBAppLookupCachePolicy = .standard,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.urlSession = urlSession
        self.cache = cache
        self.cachePolicy = cachePolicy
        self.now = now
    }

    public func fetchApps(for request: SBAppLookupRequest) async throws -> SBAppLookupResult {
        try Self.checkCancellation()
        let normalized = try Self.normalize(request)
        guard !normalized.appIDs.isEmpty else {
            return SBAppLookupResult(
                apps: [],
                missingAppIDs: [],
                source: .network,
                countryCode: normalized.countryCode
            )
        }

        let key = SBAppStoreLookupCache.Key(
            appIDs: normalized.appIDs.sorted(),
            countryCode: normalized.countryCode
        )
        let cacheSnapshot = await cache.snapshot(for: key)
        let cachedEntry = cachePolicy.usesCache ? cacheSnapshot.entry : nil
        try Self.checkCancellation()

        if let cachedEntry, isFresh(cachedEntry) {
            return Self.makeResult(
                apps: cachedEntry.apps,
                request: normalized,
                source: .freshCache
            )
        }

        do {
            let apps = try await loadApps(
                appIDs: normalized.appIDs,
                countryCode: normalized.countryCode
            )
            try Self.checkCancellation()
            if cachePolicy.usesCache {
                await cache.store(
                    apps,
                    for: key,
                    fetchedAt: now(),
                    ifGenerationMatches: cacheSnapshot.generation
                )
            }
            return Self.makeResult(apps: apps, request: normalized, source: .network)
        } catch SBAppPortfolioError.requestCancelled {
            throw SBAppPortfolioError.requestCancelled
        } catch {
            if cachePolicy.allowsStaleDataOnError, let cachedEntry {
                return Self.makeResult(
                    apps: cachedEntry.apps,
                    request: normalized,
                    source: .staleCache
                )
            }
            throw error
        }
    }

    public func invalidateCache(for request: SBAppLookupRequest) async throws {
        let normalized = try Self.normalize(request)
        let key = SBAppStoreLookupCache.Key(
            appIDs: normalized.appIDs.sorted(),
            countryCode: normalized.countryCode
        )
        await cache.removeEntry(for: key)
    }

    public func clearCache() async {
        await cache.clear()
    }

    private func isFresh(_ entry: SBAppStoreLookupCache.Entry) -> Bool {
        let age = now().timeIntervalSince(entry.fetchedAt)
        return cachePolicy.timeToLive > 0
            && age >= 0
            && age < cachePolicy.timeToLive
    }

    private func loadApps(appIDs: [String], countryCode: String) async throws -> [SBAppStoreApp] {
        let ids = appIDs.joined(separator: ",")
        var components = URLComponents(string: Self.iTunesLookupBase)
        components?.queryItems = [
            URLQueryItem(name: "id", value: ids),
            URLQueryItem(name: "country", value: countryCode),
            URLQueryItem(name: "entity", value: "software")
        ]

        guard let url = components?.url else {
            throw SBAppPortfolioError.invalidURL
        }
        var urlRequest = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData
        )
        urlRequest.timeoutInterval = 30

        do {
            let (data, response) = try await urlSession.sbData(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SBAppPortfolioError.invalidResponse
            }
            guard httpResponse.statusCode == 200 else {
                throw SBAppPortfolioError.httpError(httpResponse.statusCode)
            }

            let decoded = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: data)
            let requestedIDs = Set(appIDs)
            var seenIDs = Set<String>()
            return decoded.results.filter { app in
                let appID = String(app.trackId)
                return requestedIDs.contains(appID) && seenIDs.insert(appID).inserted
            }
        } catch is DecodingError {
            throw SBAppPortfolioError.decodingError
        } catch let error as SBAppPortfolioError {
            throw error
        } catch is CancellationError {
            throw SBAppPortfolioError.requestCancelled
        } catch let error as URLError where error.code == .cancelled {
            throw SBAppPortfolioError.requestCancelled
        } catch {
            throw SBAppPortfolioError.networkError(error.localizedDescription)
        }
    }

    private static func normalize(_ request: SBAppLookupRequest) throws -> NormalizedRequest {
        let countryCode = request.countryCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let scalars = countryCode.unicodeScalars
        guard scalars.count == 2,
              scalars.allSatisfy({ scalar in
                  (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
              }) else {
            throw SBAppPortfolioError.invalidCountryCode(request.countryCode)
        }

        var seenIDs = Set<String>()
        let appIDs = request.appIDs.compactMap { rawID -> String? in
            let appID = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !appID.isEmpty, seenIDs.insert(appID).inserted else { return nil }
            return appID
        }

        return NormalizedRequest(
            appIDs: appIDs,
            countryCode: countryCode,
            ordering: request.ordering
        )
    }

    private static func checkCancellation() throws {
        if Task.isCancelled {
            throw SBAppPortfolioError.requestCancelled
        }
    }

    private static func makeResult(
        apps: [SBAppStoreApp],
        request: NormalizedRequest,
        source: SBAppLookupSource
    ) -> SBAppLookupResult {
        let appsByID = Dictionary(uniqueKeysWithValues: apps.map { (String($0.trackId), $0) })
        let orderedApps: [SBAppStoreApp]

        switch request.ordering {
        case .caller:
            orderedApps = request.appIDs.compactMap { appsByID[$0] }
        case .displayName:
            let inputIndexes = Dictionary(
                uniqueKeysWithValues: request.appIDs.enumerated().map { ($1, $0) }
            )
            orderedApps = apps.sorted { lhs, rhs in
                let comparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                if comparison != .orderedSame { return comparison == .orderedAscending }
                return inputIndexes[String(lhs.trackId), default: .max]
                    < inputIndexes[String(rhs.trackId), default: .max]
            }
        case .response:
            orderedApps = apps
        }

        let returnedIDs = Set(appsByID.keys)
        let missingAppIDs = request.appIDs.filter { !returnedIDs.contains($0) }
        return SBAppLookupResult(
            apps: orderedApps,
            missingAppIDs: missingAppIDs,
            source: source,
            countryCode: request.countryCode
        )
    }

    static let iTunesLookupBase = "https://itunes.apple.com/lookup"

    private struct NormalizedRequest: Sendable {
        let appIDs: [String]
        let countryCode: String
        let ordering: SBAppLookupOrdering
    }
}

actor SBAppStoreLookupCache {
    struct Key: Hashable, Sendable {
        let appIDs: [String]
        let countryCode: String
    }

    struct Entry: Sendable {
        let apps: [SBAppStoreApp]
        let fetchedAt: Date
    }

    struct Generation: Sendable, Equatable {
        let allEntries: UInt64
        let key: UInt64
    }

    struct Snapshot: Sendable {
        let entry: Entry?
        let generation: Generation
    }

    private var storage: [Key: Entry] = [:]
    private var allEntriesGeneration: UInt64 = 0
    private var keyGenerations: [Key: UInt64] = [:]
    static let shared = SBAppStoreLookupCache()

    func snapshot(for key: Key) -> Snapshot {
        Snapshot(entry: storage[key], generation: generation(for: key))
    }

    func store(
        _ apps: [SBAppStoreApp],
        for key: Key,
        fetchedAt: Date,
        ifGenerationMatches generation: Generation
    ) {
        guard self.generation(for: key) == generation else { return }
        storage[key] = Entry(apps: apps, fetchedAt: fetchedAt)
    }

    func removeEntry(for key: Key) {
        storage.removeValue(forKey: key)
        keyGenerations[key, default: 0] &+= 1
    }

    func clear() {
        storage.removeAll()
        allEntriesGeneration &+= 1
        keyGenerations.removeAll()
    }

    private func generation(for key: Key) -> Generation {
        Generation(
            allEntries: allEntriesGeneration,
            key: keyGenerations[key, default: 0]
        )
    }
}

private extension URLSession {
    func sbData(for request: URLRequest) async throws -> (Data, URLResponse) {
        let taskBox = SBURLSessionTaskBox()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                let task = dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let data, let response {
                        continuation.resume(returning: (data, response))
                    } else {
                        continuation.resume(throwing: SBAppPortfolioError.invalidResponse)
                    }
                }
                taskBox.install(task)
                task.resume()
            }
        } onCancel: {
            taskBox.cancel()
        }
    }
}

private final class SBURLSessionTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionDataTask?
    private var isCancelled = false

    func install(_ task: URLSessionDataTask) {
        lock.lock()
        self.task = task
        let shouldCancel = isCancelled
        lock.unlock()

        if shouldCancel {
            task.cancel()
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let task = task
        lock.unlock()
        task?.cancel()
    }
}
