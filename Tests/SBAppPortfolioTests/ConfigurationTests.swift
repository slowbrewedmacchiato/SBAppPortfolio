//  ConfigurationTests.swift
//  SBAppPortfolioTests
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Testing
import Foundation
@testable import SBAppPortfolio

@Suite("Configuration")
struct ConfigurationTests {
    @Test("slowBrewed factory includes all six apps")
    func factoryHasSixApps() {
        let config = SBAppPortfolioConfiguration.slowBrewed(currentAppID: "")
        #expect(config.studioApps.count == 6)
    }

    @Test("visibleApps excludes currentAppID")
    func selfExclusion() {
        let config = SBAppPortfolioConfiguration.slowBrewed(currentAppID: "6781631782")
        #expect(config.studioApps.count == 6)
        #expect(config.visibleApps.count == 5)
        #expect(!config.visibleApps.contains { $0.appID == "6781631782" })
    }

    @Test("visibleApps returns all when currentAppID is empty")
    func emptyCurrentIDShowsAll() {
        let config = SBAppPortfolioConfiguration.slowBrewed(currentAppID: "")
        #expect(config.visibleApps.count == 6)
    }

    @Test("visibleApps returns all when currentAppID not in catalog")
    func unknownCurrentIDShowsAll() {
        let config = SBAppPortfolioConfiguration.slowBrewed(currentAppID: "0000000000")
        #expect(config.visibleApps.count == 6)
    }

    @Test("developerPageURL matches canonical Slow Brewed page")
    func developerPageURL() {
        let config = SBAppPortfolioConfiguration.slowBrewed(currentAppID: "")
        #expect(config.developerPageURL.absoluteString == "https://apps.apple.com/developer/id1609899925")
    }

    @Test("default lookupCountry is us")
    func defaultCountry() {
        let config = SBAppPortfolioConfiguration.slowBrewed(currentAppID: "")
        #expect(config.lookupCountry == "us")
    }

    @Test("custom catalog with custom developer URL")
    func customCatalog() {
        let apps = [
            SBAppReference(appID: "1", fallbackName: "A", fallbackDescription: "d"),
            SBAppReference(appID: "2", fallbackName: "B", fallbackDescription: "d")
        ]
        let config = SBAppPortfolioConfiguration(
            studioApps: apps,
            currentAppID: "1",
            developerPageURL: URL(string: "https://example.com/dev")!
        )
        #expect(config.studioApps.count == 2)
        #expect(config.visibleApps.count == 1)
        #expect(config.visibleApps.first?.appID == "2")
        #expect(config.developerPageURL.absoluteString == "https://example.com/dev")
    }

    @Test("SBStudioApps.slowBrewed contains all six canonical IDs")
    func canonicalCatalogIDs() {
        let ids = Set(SBStudioApps.slowBrewed.map { $0.appID })
        #expect(ids == [
            "6781631782", // AppStead
            "6755578065", // CreatorCaps
            "6751930050", // Glyppo
            "6479405901", // Glu Sight
            "6749046071", // MIRA
            "6760252774"  // Second Draft
        ])
    }
}
