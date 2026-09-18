//  CoreLookupTests.swift
//  SBAppPortfolioCoreTests
//
//  Created by Angelo Cammalleri on 2026-08-21.

import Foundation
import Testing
@testable import SBAppPortfolioCore

@Suite("Core App Store lookup", .serialized)
struct CoreLookupTests {
    @Test("Input ordering, stable de-duplication, missing IDs, and unexpected results")
    func inputOrderingAndFiltering() async throws {
        let recorder = Locked<[URL]>([])
        let session = makeSession { url in
            recorder.withValue { $0.append(url) }
            return try response(
                for: url,
                json: """
                {
                  "resultCount": 4,
                  "results": [
                    {"trackId": 2, "trackName": "Second"},
                    {"trackId": 999, "trackName": "Unexpected"},
                    {"trackId": 1, "trackName": "First"},
                    {"trackId": 2, "trackName": "Duplicate"}
                  ]
                }
                """
            )
        }
        defer { CoreStubURLProtocol.handler = nil }

        let service = makeService(session: session)
        let result = try await service.fetchApps(
            for: SBAppLookupRequest(
                appIDs: [" 1 ", "2", "1", "3", "   "],
                countryCode: " DE ",
                ordering: .input
            )
        )

        #expect(result.apps.map(\.trackId) == [1, 2])
        #expect(result.missingAppIDs == ["3"])
        #expect(result.source == .network)
        #expect(result.countryCode == "de")
        #expect(result.app(forAppID: "2")?.displayName == "Second")

        let url = try #require(recorder.value.first)
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(query.first { $0.name == "id" }?.value == "1,2,3")
        #expect(query.first { $0.name == "country" }?.value == "de")
    }

    @Test("Platform metadata preserves iOS-only apps in a mixed catalog")
    func mixedCatalogUsesHostPlatform() async throws {
        let recorder = Locked<[URL]>([])
        let session = makeSession { url in
            recorder.withValue { $0.append(url) }
            let entity = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "entity" }?.value
            let json: String
            switch entity {
            case "software":
                json = """
                {"results":[
                  {"trackId":2,"trackName":"Mobile app","description":"Mobile description",
                   "subtitle":"Mobile subtitle","artworkUrl512":"https://example.com/mobile.png",
                   "price":2.99,"formattedPrice":"$2.99"},
                  {"trackId":1,"trackName":"Universal app","description":"Mobile description"}
                ]}
                """
            case "desktopSoftware":
                json = """
                {"results":[
                  {"trackId":3,"trackName":"Desktop app","description":"Desktop-only description"},
                  {"trackId":1,"trackName":"Universal app","description":"Desktop description"},
                  {"trackId":1,"description":"Duplicate"},
                  {"trackId":999,"description":"Unexpected"}
                ]}
                """
            default:
                Issue.record("Unexpected lookup entity")
                json = "{\"results\":[]}"
            }
            return try response(for: url, json: json)
        }
        defer { CoreStubURLProtocol.handler = nil }

        let service = makeService(session: session)
        let request = SBAppLookupRequest(appIDs: ["1", "2", "3", "4"], countryCode: "de")
        let live = try await service.fetchApps(for: request)
        let cached = try await service.fetchApps(for: request)
        let responseOrder = try await service.fetchApps(
            for: SBAppLookupRequest(appIDs: ["1", "2", "3", "4"], countryCode: "de", ordering: .response)
        )
#if os(macOS)
        #expect(live.apps.map(\.trackId) == [1, 2, 3])
        #expect(live.app(forAppID: "1")?.description == "Desktop description")
        #expect(live.app(forAppID: "3")?.description == "Desktop-only description")
        #expect(live.missingAppIDs == ["4"])
        #expect(responseOrder.apps.map(\.trackId) == [2, 1, 3])
#else
        #expect(live.apps.map(\.trackId) == [1, 2])
        #expect(live.app(forAppID: "1")?.description == "Mobile description")
        #expect(live.missingAppIDs == ["3", "4"])
        #expect(responseOrder.apps.map(\.trackId) == [2, 1])
#endif
        let mobile = try #require(live.app(forAppID: "2"))
        #expect(mobile.description == "Mobile description")
        #expect(mobile.subtitle == "Mobile subtitle")
        #expect(mobile.bestArtworkURL?.absoluteString == "https://example.com/mobile.png")
        #expect(mobile.price == 2.99)
        #expect(mobile.formattedPrice == "$2.99")
        #expect(live.source == .network)
        #expect(cached.apps == live.apps)
        #expect(cached.missingAppIDs == live.missingAppIDs)
        #expect(cached.source == .freshCache)
        #expect(responseOrder.source == .freshCache)
        let queries = recorder.value.compactMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems
        }
        #expect(queries.count == requestsPerLookup)
        #expect(queries.allSatisfy { $0.first { $0.name == "id" }?.value == "1,2,3,4" })
        #expect(queries.allSatisfy { $0.first { $0.name == "country" }?.value == "de" })
        let entities = queries.compactMap { $0.first { $0.name == "entity" }?.value }
#if os(macOS)
        #expect(entities == ["software", "desktopSoftware"])
#else
        #expect(entities == ["software"])
#endif
    }

#if os(macOS)
    @Test("An empty desktop result preserves all base metadata")
    func emptyDesktopResultPreservesBase() async throws {
        let session = makeSession { url in
            let entity = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "entity" }?.value
            return try response(for: url, json: entity == "desktopSoftware"
                ? "{\"results\":[]}"
                : "{\"results\":[{\"trackId\":1,\"description\":\"Mobile description\"}]}")
        }
        defer { CoreStubURLProtocol.handler = nil }
        let result = try await makeService(session: session).fetchApps(
            for: SBAppLookupRequest(appIDs: ["1"])
        )
        #expect(result.app(forAppID: "1")?.description == "Mobile description")
        #expect(result.missingAppIDs.isEmpty)
    }

    @Test("A failed desktop request cannot cache partial base metadata")
    func failedDesktopRequestDoesNotPopulateCache() async throws {
        let baseRequests = Locked(0)
        let session = makeSession { url in
            let entity = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "entity" }?.value
            if entity == "desktopSoftware" { throw URLError(.notConnectedToInternet) }
            baseRequests.withValue { $0 += 1 }
            return try response(for: url, json: "{\"results\":[{\"trackId\":1}]}")
        }
        defer { CoreStubURLProtocol.handler = nil }
        let service = makeService(session: session)
        for _ in 0..<2 {
            await #expect(throws: SBAppPortfolioError.self) {
                _ = try await service.fetchApps(for: SBAppLookupRequest(appIDs: ["1"]))
            }
        }
        #expect(baseRequests.value == 2)
    }

    @Test("Desktop refresh errors respect stale fallback", arguments: [true, false])
    func desktopRefreshRespectsStaleFallback(allowsStale: Bool) async throws {
        let currentDate = Locked(Date(timeIntervalSince1970: 1_000))
        let failDesktop = Locked(false)
        let session = makeSession { url in
            let entity = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "entity" }?.value
            if entity == "desktopSoftware", failDesktop.value {
                throw URLError(.notConnectedToInternet)
            }
            let description = entity == "desktopSoftware" ? "Desktop description" : "Mobile description"
            return try response(for: url, json: """
                {"results":[{"trackId":1,"description":"\(description)"}]}
                """)
        }
        defer { CoreStubURLProtocol.handler = nil }
        let service = SBAppStoreLookupService(
            urlSession: session, cache: SBAppStoreLookupCache(),
            cachePolicy: SBAppLookupCachePolicy(timeToLive: 10, allowsStaleDataOnError: allowsStale),
            now: { currentDate.value }
        )
        let request = SBAppLookupRequest(appIDs: ["1"])
        let initial = try await service.fetchApps(for: request)
        currentDate.withValue { $0 = $0.addingTimeInterval(11) }
        failDesktop.withValue { $0 = true }
        if allowsStale {
            let stale = try await service.fetchApps(for: request)
            #expect(stale.source == .staleCache)
            #expect(stale.apps == initial.apps)
            #expect(stale.app(forAppID: "1")?.description == "Desktop description")
        } else {
            await #expect(throws: SBAppPortfolioError.self) {
                _ = try await service.fetchApps(for: request)
            }
        }
    }
#endif

    @Test("Response and display-name ordering remain caller selectable")
    func selectableOrdering() async throws {
        let session = makeSession { url in
            try response(
                for: url,
                json: """
                {
                  "resultCount": 2,
                  "results": [
                    {"trackId": 2, "trackName": "Zulu"},
                    {"trackId": 1, "trackName": "Alpha"}
                  ]
                }
                """
            )
        }
        defer { CoreStubURLProtocol.handler = nil }

        let service = makeService(session: session)
        let responseResult = try await service.fetchApps(
            for: SBAppLookupRequest(appIDs: ["1", "2"], ordering: .response)
        )
        let displayNameResult = try await service.fetchApps(
            for: SBAppLookupRequest(appIDs: ["1", "2"], ordering: .displayName)
        )

        #expect(responseResult.apps.map(\.trackId) == [2, 1])
        #expect(displayNameResult.apps.map(\.trackId) == [1, 2])
        #expect(displayNameResult.source == .freshCache)
    }

    @Test("An order-neutral cache key still honors each caller's input order")
    func cacheReordersForEachCaller() async throws {
        let requestCount = Locked(0)
        let session = makeSession { url in
            requestCount.withValue { $0 += 1 }
            return try response(
                for: url,
                json: """
                {"resultCount":2,"results":[
                  {"trackId":1,"trackName":"One"},
                  {"trackId":2,"trackName":"Two"}
                ]}
                """
            )
        }
        defer { CoreStubURLProtocol.handler = nil }

        let service = makeService(session: session)
        _ = try await service.fetchApps(
            for: SBAppLookupRequest(appIDs: ["1", "2"], ordering: .input)
        )
        let reversed = try await service.fetchApps(
            for: SBAppLookupRequest(appIDs: ["2", "1"], ordering: .input)
        )

        #expect(reversed.apps.map(\.trackId) == [2, 1])
        #expect(reversed.source == .freshCache)
        #expect(requestCount.value == requestsPerLookup)
    }

    @Test("Public clients with a custom URLSession do not share decoded metadata")
    func customSessionsUseIsolatedCaches() async throws {
        let requestCount = Locked(0)
        let session = makeSession { url in
            requestCount.withValue { $0 += 1 }
            return try response(
                for: url,
                json: "{\"resultCount\":1,\"results\":[{\"trackId\":1,\"trackName\":\"One\"}]}"
            )
        }
        defer { CoreStubURLProtocol.handler = nil }

        let request = SBAppLookupRequest(appIDs: ["1"])
        _ = try await SBAppStoreLookupService(urlSession: session).fetchApps(for: request)
        _ = try await SBAppStoreLookupService(urlSession: session).fetchApps(for: request)

        #expect(requestCount.value == 2 * requestsPerLookup)
    }

    @Test("The disabled cache policy neither reads nor writes decoded metadata")
    func disabledCacheDoesNotWrite() async throws {
        let requestCount = Locked(0)
        let session = makeSession { url in
            requestCount.withValue { $0 += 1 }
            return try response(
                for: url,
                json: "{\"resultCount\":1,\"results\":[{\"trackId\":1,\"trackName\":\"One\"}]}"
            )
        }
        defer { CoreStubURLProtocol.handler = nil }

        let cache = SBAppStoreLookupCache()
        let request = SBAppLookupRequest(appIDs: ["1"])
        let uncached = SBAppStoreLookupService(
            urlSession: session,
            cache: cache,
            cachePolicy: .disabled
        )
        let cached = SBAppStoreLookupService(
            urlSession: session,
            cache: cache,
            cachePolicy: .standard
        )

        _ = try await uncached.fetchApps(for: request)
        let second = try await cached.fetchApps(for: request)

        #expect(second.source == .network)
        #expect(requestCount.value == 2 * requestsPerLookup)
    }

    @Test("Invalidation prevents an older in-flight generation from repopulating cache")
    func invalidationRejectsOldGeneration() async {
        let cache = SBAppStoreLookupCache()
        let key = SBAppStoreLookupCache.Key(appIDs: ["1"], countryCode: "us")
        let oldSnapshot = await cache.snapshot(for: key)

        await cache.removeEntry(for: key)
        await cache.store(
            [SBAppStoreApp(trackId: 1, trackName: "Old")],
            for: key,
            fetchedAt: Date(),
            ifGenerationMatches: oldSnapshot.generation
        )

        #expect(await cache.snapshot(for: key).entry == nil)
    }

    @Test("Targeted invalidation evicts only the normalized request key")
    func targetedInvalidation() async throws {
        let requestCount = Locked(0)
        let session = makeSession { url in
            requestCount.withValue { $0 += 1 }
            let ids = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "id" }?.value ?? ""
            let results = ids.split(separator: ",").map { id in
                "{\"trackId\":\(id),\"trackName\":\"App \(id)\"}"
            }.joined(separator: ",")
            return try response(
                for: url,
                json: "{\"resultCount\":1,\"results\":[\(results)]}"
            )
        }
        defer { CoreStubURLProtocol.handler = nil }

        let service = makeService(session: session)
        let first = SBAppLookupRequest(appIDs: ["1"], countryCode: "US")
        let second = SBAppLookupRequest(appIDs: ["2"], countryCode: "us")

        _ = try await service.fetchApps(for: first)
        _ = try await service.fetchApps(for: second)
        try await service.invalidateCache(
            for: SBAppLookupRequest(appIDs: [" 1 "], countryCode: " us ")
        )
        let firstAgain = try await service.fetchApps(for: first)
        let secondAgain = try await service.fetchApps(for: second)

        #expect(firstAgain.source == .network)
        #expect(secondAgain.source == .freshCache)
        #expect(requestCount.value == 3 * requestsPerLookup)
    }

    @Test("Expired metadata is returned as stale when a refresh fails")
    func staleFallback() async throws {
        let currentDate = Locked(Date(timeIntervalSince1970: 1_000))
        let requestCount = Locked(0)
        let session = makeSession { url in
            let attempt = requestCount.withValue { count -> Int in
                count += 1
                return count
            }
            if attempt <= requestsPerLookup {
                return try response(
                    for: url,
                    json: "{\"resultCount\":1,\"results\":[{\"trackId\":1,\"trackName\":\"Cached\"}]}"
                )
            }
            throw URLError(.notConnectedToInternet)
        }
        defer { CoreStubURLProtocol.handler = nil }

        let service = SBAppStoreLookupService(
            urlSession: session,
            cache: SBAppStoreLookupCache(),
            cachePolicy: SBAppLookupCachePolicy(
                timeToLive: 10,
                allowsStaleDataOnError: true
            ),
            now: { currentDate.value }
        )
        let request = SBAppLookupRequest(appIDs: ["1"])

        let initial = try await service.fetchApps(for: request)
        currentDate.withValue { $0 = $0.addingTimeInterval(11) }
        let stale = try await service.fetchApps(for: request)

        #expect(initial.source == .network)
        #expect(stale.source == .staleCache)
        #expect(stale.apps.map(\.displayName) == ["Cached"])
        #expect(requestCount.value == requestsPerLookup + 1)
    }

    @Test("Disabled stale fallback surfaces refresh errors")
    func staleFallbackDisabled() async throws {
        let currentDate = Locked(Date(timeIntervalSince1970: 1_000))
        let requestCount = Locked(0)
        let session = makeSession { url in
            let attempt = requestCount.withValue { count -> Int in
                count += 1
                return count
            }
            if attempt <= requestsPerLookup {
                return try response(
                    for: url,
                    json: "{\"resultCount\":1,\"results\":[{\"trackId\":1,\"trackName\":\"Cached\"}]}"
                )
            }
            throw URLError(.notConnectedToInternet)
        }
        defer { CoreStubURLProtocol.handler = nil }

        let service = SBAppStoreLookupService(
            urlSession: session,
            cache: SBAppStoreLookupCache(),
            cachePolicy: SBAppLookupCachePolicy(
                timeToLive: 10,
                allowsStaleDataOnError: false
            ),
            now: { currentDate.value }
        )
        let request = SBAppLookupRequest(appIDs: ["1"])
        _ = try await service.fetchApps(for: request)
        currentDate.withValue { $0 = $0.addingTimeInterval(11) }

        await #expect(throws: SBAppPortfolioError.self) {
            _ = try await service.fetchApps(for: request)
        }
    }

    @Test("Invalid country codes fail before networking")
    func invalidCountryCode() async throws {
        let requestCount = Locked(0)
        let session = makeSession { url in
            requestCount.withValue { $0 += 1 }
            return try response(for: url, json: "{\"results\":[]}")
        }
        defer { CoreStubURLProtocol.handler = nil }

        let service = makeService(session: session)
        do {
            _ = try await service.fetchApps(
                for: SBAppLookupRequest(appIDs: ["1"], countryCode: "de-DE")
            )
            Issue.record("Expected invalidCountryCode")
        } catch SBAppPortfolioError.invalidCountryCode(let code) {
            #expect(code == "de-DE")
        }
        #expect(requestCount.value == 0)
    }

    @Test("Empty IDs short-circuit without networking")
    func emptyIDs() async throws {
        let requestCount = Locked(0)
        let session = makeSession { url in
            requestCount.withValue { $0 += 1 }
            return try response(for: url, json: "{\"results\":[]}")
        }
        defer { CoreStubURLProtocol.handler = nil }

        let result = try await makeService(session: session).fetchApps(
            for: SBAppLookupRequest(appIDs: ["", "   "])
        )

        #expect(result.apps.isEmpty)
        #expect(result.missingAppIDs.isEmpty)
        #expect(requestCount.value == 0)
    }

    @Test("Task cancellation cancels the macOS 11 URLSession bridge", arguments: cancellationEntities)
    func cancellationCancelsURLSessionTask(entity: String) async throws {
        CancellationStubURLProtocol.suspendedEntity.withValue { $0 = entity }
        CancellationStubURLProtocol.started.withValue { $0 = false }
        CancellationStubURLProtocol.stopped.withValue { $0 = false }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CancellationStubURLProtocol.self]
        let service = makeService(session: URLSession(configuration: configuration))

        let task = Task {
            try await service.fetchApps(for: SBAppLookupRequest(appIDs: ["1"]))
        }

        for _ in 0..<200 where !CancellationStubURLProtocol.started.value {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        #expect(CancellationStubURLProtocol.started.value)
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected requestCancelled")
        } catch SBAppPortfolioError.requestCancelled {
            // Expected: cancellation must not be converted to a network error.
        }

        #expect(CancellationStubURLProtocol.stopped.value)
    }

    @Test("A pre-cancelled caller cannot receive a fresh cache hit")
    func preCancelledCacheHit() async throws {
        let session = makeSession { url in
            try response(
                for: url,
                json: "{\"resultCount\":1,\"results\":[{\"trackId\":1,\"trackName\":\"One\"}]}"
            )
        }
        defer { CoreStubURLProtocol.handler = nil }

        let service = makeService(session: session)
        let request = SBAppLookupRequest(appIDs: ["1"])
        _ = try await service.fetchApps(for: request)

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.fetchApps(for: request)
        }

        do {
            _ = try await task.value
            Issue.record("Expected requestCancelled")
        } catch SBAppPortfolioError.requestCancelled {
            // Expected: cache access follows the same cancellation contract.
        }
    }

    @Test("The highest-resolution valid artwork URL is preferred")
    func bestArtworkURL() {
        let highResolution = SBAppStoreApp(
            trackId: 1,
            artworkUrl100: "https://example.com/100.png",
            artworkUrl512: "https://example.com/512.png"
        )
        let fallback = SBAppStoreApp(
            trackId: 2,
            artworkUrl100: "https://example.com/100.png"
        )

        #expect(highResolution.bestArtworkURL?.absoluteString == "https://example.com/512.png")
        #expect(fallback.bestArtworkURL?.absoluteString == "https://example.com/100.png")
    }

    private static var cancellationEntities: [String] {
#if os(macOS)
        ["software", "desktopSoftware"]
#else
        ["software"]
#endif
    }

    private var requestsPerLookup: Int {
#if os(macOS)
        2
#else
        1
#endif
    }

    private func makeService(session: URLSession) -> SBAppStoreLookupService {
        SBAppStoreLookupService(
            urlSession: session,
            cache: SBAppStoreLookupCache(),
            cachePolicy: .standard
        )
    }

    private func makeSession(
        handler: @escaping @Sendable (URL) throws -> (Data, HTTPURLResponse)
    ) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CoreStubURLProtocol.self]
        CoreStubURLProtocol.handler = handler
        return URLSession(configuration: configuration)
    }

    private func response(
        for url: URL,
        statusCode: Int = 200,
        json: String
    ) throws -> (Data, HTTPURLResponse) {
        let response = try #require(
            HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        )
        return (Data(json.utf8), response)
    }
}

private final class CoreStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URL) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        do {
            let (data, response) = try handler(url)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class CancellationStubURLProtocol: URLProtocol {
    static let suspendedEntity = Locked("software")
    static let started = Locked(false)
    static let stopped = Locked(false)

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let url = request.url,
           let entity = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "entity" })?.value,
           entity != Self.suspendedEntity.value {
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("{\"results\":[{\"trackId\":1}]}".utf8))
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        Self.started.withValue { $0 = true }
    }

    override func stopLoading() {
        Self.stopped.withValue { $0 = true }
    }
}

private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Value

    init(_ value: Value) {
        storage = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    @discardableResult
    func withValue<Result>(_ operation: (inout Value) throws -> Result) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try operation(&storage)
    }
}
