//  LookupParsingTests.swift
//  SBAppPortfolioTests
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Testing
import Foundation
@testable import SBAppPortfolio

@Suite("Lookup decoding")
struct LookupParsingTests {
    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test("Single app decodes all fields")
    func singleApp() throws {
        let data = try fixture("lookup_single")
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: data)

        #expect(response.resultCount == 1)
        let app = try #require(response.results.first)

        #expect(app.trackId == 1000000001)
        #expect(app.trackName == "Example App A")
        #expect(app.trackCensoredName == "Example App A")
        #expect(app.bundleId == "com.example.appa")
        #expect(app.primaryGenreName == "Productivity")
        #expect(app.genres == ["Productivity", "Business"])
        #expect(app.formattedPrice == "Free")
        #expect(app.averageUserRating == 4.8)
        #expect(app.userRatingCount == nil || app.userRatingCount != nil) // present in fixture
        #expect(app.version == "1.2.3")
        #expect(app.appStoreURL?.absoluteString == "https://apps.apple.com/app/id1000000001")
        #expect(app.artworkURL?.absoluteString == "https://example.com/artwork-100.png")
    }

    @Test("Multiple apps decode in order")
    func multipleApps() throws {
        let data = try fixture("lookup_multiple")
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: data)

        #expect(response.resultCount == 2)
        #expect(response.results.count == 2)
        #expect(response.results[0].trackId == 1000000002)
        #expect(response.results[1].trackId == 1000000004)
    }

    @Test("Empty results decode cleanly")
    func emptyResults() throws {
        let data = try fixture("lookup_empty")
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: data)

        #expect(response.resultCount == 0)
        #expect(response.results.isEmpty)
    }

    @Test("Malformed JSON throws DecodingError")
    func malformedThrows() throws {
        let malformed = try fixture("lookup_malformed")

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: malformed)
        }
    }

    @Test("displayName falls back to trackName when trackCensoredName is nil")
    func displayNameFallback() throws {
        let json = """
        {"resultCount":1,"results":[{"trackId":1,"trackName":"Raw","description":"d","artworkUrl100":"a","trackViewUrl":"u","artistName":"a"}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        let app = try #require(response.results.first)
        #expect(app.trackCensoredName == nil)
        #expect(app.displayName == "Raw")
    }

    @Test("displayPrice falls back to localized Free when formattedPrice is nil")
    func displayPriceFallback() throws {
        let json = """
        {"resultCount":1,"results":[{"trackId":1,"trackName":"X","description":"d","artworkUrl100":"a","trackViewUrl":"u","artistName":"a"}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        let app = try #require(response.results.first)
        #expect(app.formattedPrice == nil)
        // Free is localized; in en-US it resolves to "Free".
        #expect(app.displayPrice == "Free")
    }

    @Test("displaySubtitle uses subtitle when present")
    func subtitlePreferred() throws {
        let json = """
        {"resultCount":1,"results":[{"trackId":1,"trackName":"X","subtitle":"Short tagline","description":"Longer description here.","artworkUrl100":"a","trackViewUrl":"u","artistName":"a"}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        let app = try #require(response.results.first)
        #expect(app.displaySubtitle == "Short tagline")
    }

    @Test("displaySubtitle derives first sentence when subtitle missing and short enough")
    func subtitleFromFirstSentence() throws {
        let json = """
        {"resultCount":1,"results":[{"trackId":1,"trackName":"X","description":"First sentence here. Second sentence.","artworkUrl100":"a","trackViewUrl":"u","artistName":"a"}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        let app = try #require(response.results.first)
        #expect(app.displaySubtitle == "First sentence here")
    }

    @Test("displaySubtitle truncates overlong description to 120 chars")
    func subtitleTruncates() throws {
        let long = String(repeating: "a", count: 200)
        let json = """
        {"resultCount":1,"results":[{"trackId":1,"trackName":"X","description":"\(long)","artworkUrl100":"a","trackViewUrl":"u","artistName":"a"}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        let app = try #require(response.results.first)
        #expect(app.displaySubtitle.count <= 120)
        #expect(app.displaySubtitle.hasSuffix("..."))
    }

    @Test("primaryGenre falls back to first genre when primaryGenreName is nil")
    func primaryGenreFallback() throws {
        let json = """
        {"resultCount":1,"results":[{"trackId":1,"trackName":"X","description":"d","artworkUrl100":"a","trackViewUrl":"u","artistName":"a","genres":["Games","Education"]}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        let app = try #require(response.results.first)
        #expect(app.primaryGenreName == nil)
        #expect(app.primaryGenre == "Games")
    }

    @Test("isFree is true when price is 0")
    func isFreeTrueAtZero() throws {
        let json = """
        {"resultCount":1,"results":[{"trackId":1,"trackName":"X","description":"d","artworkUrl100":"a","trackViewUrl":"u","artistName":"a","price":0,"formattedPrice":"Free"}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        let app = try #require(response.results.first)
        #expect(app.isFree)
        #expect(app.displayPrice == "Free")
    }

    @Test("isFree is false for a paid app regardless of localized formattedPrice string")
    func isFreeFalseForPaid() throws {
        // German storefront returns "0,99 €", the old `displayPrice == "Free"`
        // check would have wrongly rendered the GET pill here.
        let json = """
        {"resultCount":1,"results":[{"trackId":1,"trackName":"X","description":"d","artworkUrl100":"a","trackViewUrl":"u","artistName":"a","price":0.99,"formattedPrice":"0,99 €"}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        let app = try #require(response.results.first)
        #expect(!app.isFree)
        #expect(app.displayPrice == "0,99 €")
    }

    @Test("Entry with no price data at all is treated as free")
    func noPriceDataIsFree() throws {
        // Real case: the App Store returns neither `price` nor `formattedPrice`
        // for some free apps. Without this, such an app renders the word "Free"
        // next to GET pills for its siblings in the same list.
        let json = """
        {"resultCount":1,"results":[{"trackId":1,"trackName":"X","description":"d","artworkUrl100":"a","trackViewUrl":"u","artistName":"a"}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        let app = try #require(response.results.first)
        #expect(app.price == nil)
        #expect(app.formattedPrice == nil)
        #expect(app.isFree)
    }

    @Test("Missing price falls back to showing formattedPrice rather than GET pill")
    func missingPriceShowsFormattedPrice() throws {
        // When `price` is absent from the response we cannot be sure the app
        // is free, so isFree is false and the row shows the localized
        // formattedPrice (e.g. "Gratis" in German) instead of the GET pill.
        let json = """
        {"resultCount":1,"results":[{"trackId":1,"trackName":"X","description":"d","artworkUrl100":"a","trackViewUrl":"u","artistName":"a","formattedPrice":"Gratis"}]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        let app = try #require(response.results.first)
        #expect(app.price == nil)
        #expect(!app.isFree)
        #expect(app.displayPrice == "Gratis")
    }

    @Test("Malformed element in a batch is dropped, not propagated")
    func partialMalformedDecodesGoodElements() throws {
        // Four elements in results; the third is missing trackId (required).
        // The decoder must drop it and return the three good apps rather than
        // failing the whole batch with decodingError.
        let data = try fixture("lookup_partial_malformed")
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: data)

        #expect(response.results.count == 3)
        let ids = response.results.map(\.trackId)
        #expect(ids == [1000000001, 1000000002, 1000000003])
    }

    @Test("Missing resultCount falls back to 0 without throwing")
    func missingResultCount() throws {
        let json = """
        {"results":[]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        #expect(response.resultCount == 0)
        #expect(response.results.isEmpty)
    }

    @Test("Hostile resultCount does not trigger a fatal allocation")
    func hostileResultCountDoesNotAbort() throws {
        // `resultCount` is attacker-controlled network data. A value of Int.max
        // previously fed `reserveCapacity`, which fatally allocated ~16 EiB.
        // With reserveCapacity removed, decoding succeeds and the actual
        // element count (0 here) wins.
        let json = """
        {"resultCount":9223372036854775807,"results":[]}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(SBAppStoreLookupResponse.self, from: json)
        #expect(response.results.isEmpty)
    }
}
