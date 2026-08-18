//  SBAppStoreApp.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Foundation

/// A single app's live App Store metadata, decoded from the iTunes Lookup API.
///
/// All field names match the iTunes Lookup JSON keys exactly. Computed
/// helpers normalize display values (name, price, subtitle, genre) with
/// sensible fallbacks.
public struct SBAppStoreApp: Codable, Identifiable, Sendable {
    public let trackId: Int
    public let trackName: String?
    public let trackCensoredName: String?
    public let subtitle: String?
    public let description: String?
    public let artworkUrl100: String?
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

    /// Falls back to "Free" when the App Store omits `formattedPrice`.
    public var displayPrice: String {
        formattedPrice ?? String(localized: "Free", bundle: .module, comment: "Fallback price label when App Store lookup omits formatted price.")
    }

    /// Locale-independent signal that the app is free. Based on the numeric
    /// `price` field (0 for free apps) rather than the localized
    /// `formattedPrice` string ("Free" / "Gratis" / "無料" / etc.), so the
    /// GET pill renders correctly regardless of `lookupCountry`.
    public var isFree: Bool {
        price == 0
    }

    /// Prefers the censored name (used by the App Store in some regions) over
    /// the raw track name. Falls back to a localized "App" label when both
    /// are missing so the row never shows an empty title.
    public var displayName: String {
        trackCensoredName ?? trackName ?? String(localized: "App", bundle: .module, comment: "Fallback name label when App Store lookup omits track name.")
    }

    /// Falls back to the first genre when `primaryGenreName` is missing.
    public var primaryGenre: String {
        primaryGenreName ?? genres?.first ?? String(localized: "App", bundle: .module, comment: "Fallback genre label for portfolio rows.")
    }

    /// Returns the App Store subtitle when present; otherwise derives a short
    /// summary from the description (first sentence, or first 120 characters).
    /// Returns an empty string when both subtitle and description are missing.
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
        guard let trackViewUrl else { return nil }
        return URL(string: trackViewUrl)
    }

    public var artworkURL: URL? {
        guard let artworkUrl100 else { return nil }
        return URL(string: artworkUrl100)
    }
}

/// Envelope returned by the iTunes Lookup endpoint.
///
/// Decodes `results` with per-element isolation: a single malformed entry
/// (missing required field, wrong type, etc.) is dropped rather than failing
/// the whole batch. This matters for the batched lookup path where one bad
/// sibling-app payload would otherwise blank the entire sheet.
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
        // `superDecoder()` returns a fresh decoder for the current element and
        // advances the iterator, so each element decodes in isolation. A
        // malformed entry (missing trackId, wrong type, etc.) is dropped via
        // `try?` rather than failing the whole batch.
        //
        // Note: do NOT pre-size `apps` from `resultCount` — that field is
        // attacker-controlled network data. A hostile `resultCount: Int.max`
        // would trigger a fatal allocation via `reserveCapacity` before the
        // loop runs, defeating the per-element isolation. Let the array grow
        // naturally from successfully decoded elements.
        while !unkeyed.isAtEnd {
            let elementDecoder = try unkeyed.superDecoder()
            if let app = try? SBAppStoreApp(from: elementDecoder) {
                apps.append(app)
            }
        }
        results = apps
    }
}
