//  SBAppStoreApp.swift
//  SBAppPortfolioCore
//
//  Created by Angelo Cammalleri on 2026-08-21.

import Foundation

/// A single app's live metadata decoded from Apple's iTunes Lookup API.
public struct SBAppStoreApp: Codable, Identifiable, Sendable, Equatable {
    public let trackId: Int
    public let trackName: String?
    public let trackCensoredName: String?
    public let subtitle: String?
    public let description: String?
    public let artworkUrl100: String?
    public let artworkUrl512: String?
    public let trackViewUrl: String?
    public let artistName: String?
    public let bundleId: String?
    public let primaryGenreName: String?
    public let genres: [String]?
    public let formattedPrice: String?
    public let price: Double?
    public let averageUserRating: Double?
    public let userRatingCount: Int?
    public let version: String?
    public let releaseDate: String?

    public var id: Int { trackId }

    public init(
        trackId: Int,
        trackName: String? = nil,
        trackCensoredName: String? = nil,
        subtitle: String? = nil,
        description: String? = nil,
        artworkUrl100: String? = nil,
        artworkUrl512: String? = nil,
        trackViewUrl: String? = nil,
        artistName: String? = nil,
        bundleId: String? = nil,
        primaryGenreName: String? = nil,
        genres: [String]? = nil,
        formattedPrice: String? = nil,
        price: Double? = nil,
        averageUserRating: Double? = nil,
        userRatingCount: Int? = nil,
        version: String? = nil,
        releaseDate: String? = nil
    ) {
        self.trackId = trackId
        self.trackName = trackName
        self.trackCensoredName = trackCensoredName
        self.subtitle = subtitle
        self.description = description
        self.artworkUrl100 = artworkUrl100
        self.artworkUrl512 = artworkUrl512
        self.trackViewUrl = trackViewUrl
        self.artistName = artistName
        self.bundleId = bundleId
        self.primaryGenreName = primaryGenreName
        self.genres = genres
        self.formattedPrice = formattedPrice
        self.price = price
        self.averageUserRating = averageUserRating
        self.userRatingCount = userRatingCount
        self.version = version
        self.releaseDate = releaseDate
    }

    /// Falls back to an English label when the lookup omits a formatted price.
    /// Presentation modules can replace this label with their localized copy.
    public var displayPrice: String {
        formattedPrice ?? "Free"
    }

    /// A locale-independent signal that the app is free.
    public var isFree: Bool {
        if let price { return price == 0 }
        return formattedPrice == nil
    }

    /// Prefers the censored App Store name over the raw track name.
    public var displayName: String {
        trackCensoredName ?? trackName ?? "App"
    }

    /// Falls back to the first genre when the primary genre is absent.
    public var primaryGenre: String {
        primaryGenreName ?? genres?.first ?? "App"
    }

    /// Uses the App Store subtitle when available, then derives a short summary
    /// from the first description sentence or the first 120 characters.
    public var displaySubtitle: String {
        if let subtitle, !subtitle.isEmpty {
            return subtitle
        }

        guard let description, !description.isEmpty else {
            return ""
        }

        let sentences = description.components(separatedBy: ". ")
        if let firstSentence = sentences.first, firstSentence.count <= 120 {
            return firstSentence
        }

        if description.count <= 120 {
            return description
        }

        return String(description.prefix(117)) + "..."
    }

    public var appStoreURL: URL? {
        trackViewUrl.flatMap(URL.init(string:))
    }

    /// The original 100 pixel artwork URL retained for source compatibility.
    public var artworkURL: URL? {
        artworkUrl100.flatMap(URL.init(string:))
    }

    /// The highest resolution artwork supplied by the lookup response, with a
    /// fallback to the 100 pixel variant when 512 pixel artwork is unavailable.
    public var bestArtworkURL: URL? {
        artworkUrl512.flatMap(URL.init(string:)) ?? artworkURL
    }
}

/// Envelope returned by the iTunes Lookup endpoint.
///
/// Every result element decodes independently, so one malformed entry does
/// not invalidate the rest of a batched response.
struct SBAppStoreLookupResponse: Codable, Sendable {
    let resultCount: Int
    let results: [SBAppStoreApp]

    private enum CodingKeys: String, CodingKey {
        case resultCount, results
    }

    init(resultCount: Int = 0, results: [SBAppStoreApp] = []) {
        self.resultCount = resultCount
        self.results = results
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        resultCount = try container.decodeIfPresent(Int.self, forKey: .resultCount) ?? 0

        var unkeyed = try container.nestedUnkeyedContainer(forKey: .results)
        var apps: [SBAppStoreApp] = []
        while !unkeyed.isAtEnd {
            let elementDecoder = try unkeyed.superDecoder()
            if let app = try? SBAppStoreApp(from: elementDecoder) {
                apps.append(app)
            }
        }
        results = apps
    }
}
