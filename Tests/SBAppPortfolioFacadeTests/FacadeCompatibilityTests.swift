//  FacadeCompatibilityTests.swift
//  SBAppPortfolioFacadeTests
//
//  Created by Angelo Cammalleri on 2026-08-21.

import Foundation
import Testing
import SBAppPortfolio

@Suite("SBAppPortfolio compatibility facade")
struct FacadeCompatibilityTests {
    @Test("Existing consumers need only the original module import")
    func originalModuleExposesMovedTypes() {
        let reference = SBAppReference(
            appID: "1",
            fallbackName: "One",
            fallbackDescription: "Fallback"
        )
        let app = SBAppStoreApp(trackId: 1, trackName: "One")
        let request = SBAppLookupRequest(appIDs: [reference.appID])
        let result = SBAppLookupResult(
            apps: [app],
            missingAppIDs: [],
            source: .network,
            countryCode: "us"
        )

        #expect(request.ordering == .caller)
        #expect(result.app(forAppID: reference.appID) == app)
    }

    @Test("The legacy configuration overload remains callable")
    func legacyFetchSignatureCompiles() {
        let fetch: @Sendable (
            SBAppStoreLookupService,
            SBAppPortfolioConfiguration
        ) async throws -> [SBAppStoreApp] = { service, configuration in
            try await service.fetchApps(for: configuration)
        }

        _ = fetch
    }

    @Test("The reusable Store action pill supports GET and custom titles")
    @MainActor
    func actionPillInitializersCompile() {
        _ = SBAppPortfolioActionPill()
        _ = SBAppPortfolioActionPill(title: "$1.99")
    }
}
