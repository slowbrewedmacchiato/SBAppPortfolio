//  ServiceTests.swift
//  SBAppPortfolioTests
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Testing
import Foundation
import os
@testable import SBAppPortfolio

@Suite("Lookup service", .serialized)
struct ServiceTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func makeSession(respondingWith handler: @escaping @Sendable (URL) throws -> (Data, HTTPURLResponse)) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.handler = handler
        return URLSession(configuration: config)
    }

    @Test("Successful batched fetch returns parsed apps sorted by name")
    func success() async throws {
        let batch = try fixture("lookup_batch")

        let session = makeSession { url in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (batch, response)
        }
        defer { StubURLProtocol.handler = nil }

        let config = SBAppPortfolioConfiguration(
            studioApps: [
                SBAppReference(appID: "1000000001", fallbackName: "Example App A", fallbackDescription: "d"),
                SBAppReference(appID: "1000000002", fallbackName: "Example App B", fallbackDescription: "d")
            ],
            currentAppID: "",
            developerPageURL: URL(string: "https://example.com")!,
            urlSession: session
        )

        let service = SBAppStoreLookupService(urlSession: session, cache: SBAppStoreLookupCache())
        let apps = try await service.fetchApps(for: config)

        #expect(apps.count == 2)
        #expect(apps.map(\.displayName) == ["Example App A", "Example App B"])
    }

    @Test("lookupCountry reaches the request query string")
    func lookupCountryInQuery() async throws {
        let batch = try fixture("lookup_batch")
        let capturedURL = OSAllocatedUnfairLock<URL?>(initialState: nil)

        let session = makeSession { url in
            capturedURL.withLock { $0 = url }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (batch, response)
        }
        defer { StubURLProtocol.handler = nil }

        let config = SBAppPortfolioConfiguration(
            studioApps: [
                SBAppReference(appID: "1000000001", fallbackName: "Example App A", fallbackDescription: "d"),
                SBAppReference(appID: "1000000002", fallbackName: "Example App B", fallbackDescription: "d")
            ],
            currentAppID: "",
            developerPageURL: URL(string: "https://example.com")!,
            lookupCountry: "jp",
            urlSession: session
        )

        let service = SBAppStoreLookupService(urlSession: session, cache: SBAppStoreLookupCache())
        _ = try await service.fetchApps(for: config)

        let url = try #require(capturedURL.withLock { $0 })
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = try #require(components.queryItems)
        let country = try #require(query.first { $0.name == "country" }?.value)
        let id = try #require(query.first { $0.name == "id" }?.value)

        #expect(country == "jp")
        #expect(id == "1000000001,1000000002")
    }

    @Test("Self-exclusion removes currentAppID before batching")
    func selfExclusionBeforeFetch() async throws {
        let batch = try fixture("lookup_batch")

        let capturedID = OSAllocatedUnfairLock<String?>(initialState: nil)
        let session = makeSession { url in
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            capturedID.withLock { $0 = components?.queryItems?.first { $0.name == "id" }?.value }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (batch, response)
        }
        defer { StubURLProtocol.handler = nil }

        let config = SBAppPortfolioConfiguration(
            studioApps: [
                SBAppReference(appID: "1000000001", fallbackName: "Example App A", fallbackDescription: "d"),
                SBAppReference(appID: "1000000002", fallbackName: "Example App B", fallbackDescription: "d")
            ],
            currentAppID: "1000000001",
            developerPageURL: URL(string: "https://example.com")!,
            urlSession: session
        )

        let service = SBAppStoreLookupService(urlSession: session, cache: SBAppStoreLookupCache())
        _ = try await service.fetchApps(for: config)

        let id = try #require(capturedID.withLock { $0 })
        #expect(id == "1000000002")
        #expect(!id.contains("1000000001"))
    }

    @Test("HTTP 404 maps to httpError")
    func http404() async throws {
        let session = makeSession { url in
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
        defer { StubURLProtocol.handler = nil }

        let config = SBAppPortfolioConfiguration(
            studioApps: [SBAppReference(appID: "1", fallbackName: "A", fallbackDescription: "d")],
            currentAppID: "",
            developerPageURL: URL(string: "https://example.com")!,
            urlSession: session
        )

        let service = SBAppStoreLookupService(urlSession: session, cache: SBAppStoreLookupCache())
        await #expect(throws: SBAppPortfolioError.self) {
            _ = try await service.fetchApps(for: config)
        }
    }

    @Test("Malformed JSON maps to decodingError")
    func malformedJSON() async throws {
        let malformed = try fixture("lookup_malformed")
        let session = makeSession { url in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (malformed, response)
        }
        defer { StubURLProtocol.handler = nil }

        let config = SBAppPortfolioConfiguration(
            studioApps: [SBAppReference(appID: "1", fallbackName: "A", fallbackDescription: "d")],
            currentAppID: "",
            developerPageURL: URL(string: "https://example.com")!,
            urlSession: session
        )

        let service = SBAppStoreLookupService(urlSession: session, cache: SBAppStoreLookupCache())
        do {
            _ = try await service.fetchApps(for: config)
            Issue.record("Expected decodingError")
        } catch SBAppPortfolioError.decodingError {
            // expected
        } catch {
            Issue.record("Wrong error: \(error)")
        }
    }

    @Test("Empty results return empty array, not an error")
    func emptyResults() async throws {
        let empty = try fixture("lookup_empty")
        let session = makeSession { url in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (empty, response)
        }
        defer { StubURLProtocol.handler = nil }

        let config = SBAppPortfolioConfiguration(
            studioApps: [SBAppReference(appID: "1", fallbackName: "A", fallbackDescription: "d")],
            currentAppID: "",
            developerPageURL: URL(string: "https://example.com")!,
            urlSession: session
        )

        let service = SBAppStoreLookupService(urlSession: session, cache: SBAppStoreLookupCache())
        let apps = try await service.fetchApps(for: config)
        #expect(apps.isEmpty)
    }

    @Test("Empty visibleApps short-circuits without a network call")
    func emptyVisibleApps() async throws {
        let counter = OSAllocatedUnfairLock(initialState: 0)
        let session = makeSession { url in
            counter.withLock { $0 += 1 }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        }
        defer { StubURLProtocol.handler = nil }

        let config = SBAppPortfolioConfiguration(
            studioApps: [SBAppReference(appID: "1", fallbackName: "A", fallbackDescription: "d")],
            currentAppID: "1",
            developerPageURL: URL(string: "https://example.com")!,
            urlSession: session
        )

        let service = SBAppStoreLookupService(urlSession: session, cache: SBAppStoreLookupCache())
        let apps = try await service.fetchApps(for: config)
        #expect(apps.isEmpty)
        #expect(counter.withLock { $0 } == 0)
    }

    @Test("Cache hit returns cached apps without a second network call")
    func cacheHit() async throws {
        let counter = OSAllocatedUnfairLock(initialState: 0)
        let batch = try fixture("lookup_batch")
        let session = makeSession { url in
            counter.withLock { $0 += 1 }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (batch, response)
        }
        defer { StubURLProtocol.handler = nil }

        let config = SBAppPortfolioConfiguration(
            studioApps: [SBAppReference(appID: "1000000001", fallbackName: "Example App A", fallbackDescription: "d")],
            currentAppID: "",
            developerPageURL: URL(string: "https://example.com")!,
            urlSession: session
        )

        let service = SBAppStoreLookupService(urlSession: session, cache: SBAppStoreLookupCache())
        _ = try await service.fetchApps(for: config) // network
        _ = try await service.fetchApps(for: config) // cache

        #expect(counter.withLock { $0 } == 1)
    }

    @Test("clearCache forces a fresh fetch on next call")
    func clearCache() async throws {
        let counter = OSAllocatedUnfairLock(initialState: 0)
        let batch = try fixture("lookup_batch")
        let session = makeSession { url in
            counter.withLock { $0 += 1 }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (batch, response)
        }
        defer { StubURLProtocol.handler = nil }

        let config = SBAppPortfolioConfiguration(
            studioApps: [SBAppReference(appID: "1000000001", fallbackName: "Example App A", fallbackDescription: "d")],
            currentAppID: "",
            developerPageURL: URL(string: "https://example.com")!,
            urlSession: session
        )

        let service = SBAppStoreLookupService(urlSession: session, cache: SBAppStoreLookupCache())
        _ = try await service.fetchApps(for: config) // network
        await service.clearCache()
        _ = try await service.fetchApps(for: config) // network again

        #expect(counter.withLock { $0 } == 2)
    }

    @Test("Shared cache persists across service instances (sheet-dismissal scenario)")
    func sharedCacheSurvivesRecreation() async throws {
        let counter = OSAllocatedUnfairLock(initialState: 0)
        let batch = try fixture("lookup_batch")
        let session = makeSession { url in
            counter.withLock { $0 += 1 }
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (batch, response)
        }
        defer { StubURLProtocol.handler = nil }

        let config = SBAppPortfolioConfiguration(
            studioApps: [SBAppReference(appID: "1000000001", fallbackName: "Example App A", fallbackDescription: "d")],
            currentAppID: "",
            developerPageURL: URL(string: "https://example.com")!,
            urlSession: session
        )

        // Wipe the shared cache first so the test is hermetic.
        await SBAppStoreLookupCache.shared.clear()

        let serviceA = SBAppStoreLookupService(urlSession: session)
        _ = try await serviceA.fetchApps(for: config) // network

        // New service instance, same shared cache — should hit, not network.
        let serviceB = SBAppStoreLookupService(urlSession: session)
        let apps = try await serviceB.fetchApps(for: config)

        // The stub returns the full 2-app batch fixture regardless of the
        // requested ID; the point of this test is the network-call count, not
        // the app count.
        #expect(apps.count == 2)
        #expect(counter.withLock { $0 } == 1)

        // Clean up so the shared cache doesn't leak to subsequent tests.
        await SBAppStoreLookupCache.shared.clear()
    }
}

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: (@Sendable (URL) throws -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (data, response) = try handler(request.url!)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
