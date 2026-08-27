//  PresentationTests.swift
//  SBAppPortfolioTests
//
//  Created by Angelo Cammalleri on 2026-08-21.

import Foundation
import Testing
@testable import SBAppPortfolio

@Suite("Portfolio presentation")
struct PresentationTests {
    private let reference = SBAppReference(
        appID: "123",
        fallbackName: "Fallback App",
        fallbackDescription: "Curated fallback."
    )

    @Test("Default presentation preserves the original sheet policy")
    func defaultPresentation() {
        let presentation = SBAppPortfolioPresentation.standard

        #expect(presentation.currentAppBehavior == .exclude)
        #expect(presentation.ordering == .alphabetical)
        #expect(presentation.summaryPolicy == .appStoreSubtitleThenDescription)
        #expect(presentation.showsDoneButton)
        #expect(presentation.showsDeveloperLink)
        #expect(presentation.showsPrice)
        #expect(presentation.showsGenre)
    }

    @Test("A missing lookup result produces a complete fallback item")
    func fallbackItem() {
        let item = SBAppPortfolioItem(reference: reference)

        #expect(item.name == "Fallback App")
        #expect(item.summary == "Curated fallback.")
        #expect(item.appStoreURL?.absoluteString == "https://apps.apple.com/app/id123")
        #expect(item.artworkURL == nil)
        #expect(!item.hasLiveMetadata)
    }

    @Test("Live metadata overlays title, subtitle, destination, and best artwork")
    func liveOverlay() {
        let app = SBAppStoreApp(
            trackId: 123,
            trackName: "Live App",
            subtitle: "Real subtitle",
            description: "Longer description.",
            artworkUrl100: "https://example.com/100.png",
            artworkUrl512: "https://example.com/512.png",
            trackViewUrl: "https://apps.apple.com/de/app/live/id123",
            primaryGenreName: "Utilities",
            formattedPrice: "0,99 €",
            price: 0.99
        )
        let item = SBAppPortfolioItem(
            reference: reference,
            storeApp: app,
            summaryPolicy: .appStoreSubtitleThenFallback
        )

        #expect(item.name == "Live App")
        #expect(item.summary == "Real subtitle")
        #expect(item.appStoreURL?.absoluteString == "https://apps.apple.com/de/app/live/id123")
        #expect(item.artworkURL?.absoluteString == "https://example.com/512.png")
        #expect(item.genre == "Utilities")
        #expect(item.formattedPrice == "0,99 €")
        #expect(!item.isFree)
        #expect(item.hasLiveMetadata)
    }

    @Test("Curated summary remains when Apple omits the subtitle")
    func missingSubtitleKeepsFallback() {
        let app = SBAppStoreApp(
            trackId: 123,
            trackName: "Live App",
            description: "A description that should not replace approved copy."
        )
        let item = SBAppPortfolioItem(
            reference: reference,
            storeApp: app,
            summaryPolicy: .appStoreSubtitleThenFallback
        )

        #expect(item.summary == "Curated fallback.")
    }

    @Test("Original summary policy still derives a short description")
    func descriptionSummaryCompatibility() {
        let app = SBAppStoreApp(
            trackId: 123,
            description: "First sentence. Second sentence."
        )
        let item = SBAppPortfolioItem(reference: reference, storeApp: app)

        #expect(item.summary == "First sentence")
    }

    @Test("Fallback-only policy ignores mutable store copy")
    func fallbackOnly() {
        let app = SBAppStoreApp(
            trackId: 123,
            subtitle: "Store subtitle",
            description: "Store description."
        )
        let item = SBAppPortfolioItem(
            reference: reference,
            storeApp: app,
            summaryPolicy: .fallbackOnly
        )

        #expect(item.summary == "Curated fallback.")
    }
}
