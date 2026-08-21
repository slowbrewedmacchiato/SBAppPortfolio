# SBAppPortfolio

[![CI](https://github.com/slowbrewedmacchiato/SBAppPortfolio/actions/workflows/ci.yml/badge.svg)](https://github.com/slowbrewedmacchiato/SBAppPortfolio/actions/workflows/ci.yml)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Core-iOS%2016%20%7C%20macOS%2011%20%7C%20watchOS%209%20%7C%20tvOS%2016%20%7C%20visionOS%201-blue.svg)](https://developer.apple.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-DocC-informational.svg)](https://slowbrewedmacchiato.github.io/SBAppPortfolio/documentation/sbappportfolio)

**Live App Store metadata and a reusable “More From Us” experience for studios that ship more than one app.**

SBAppPortfolio now ships two library products:

| Product | Use it when | Platforms |
| --- | --- | --- |
| `SBAppPortfolioCore` | Your app or design system owns the catalog, fallback copy, ordering, routing, and UI. Core performs a typed, batched iTunes Lookup request and returns raw metadata. | iOS 16+, macOS 11+, watchOS 9+, tvOS 16+, visionOS 1+ |
| `SBAppPortfolio` | You want the localized, batteries-included SwiftUI sheet and optional reusable row. It depends on Core and preserves the original 1.0 integration. | iOS 18+, macOS 13+ |

Both products add no external runtime dependencies. The Core product imports Foundation only; it does not own presentation policy or SwiftUI.

## Requirements

- Swift 6.0+
- Xcode 16+
- A deployment target supported by the product selected above

## Installation

Add the package in Xcode with File ▸ Add Package Dependencies… or declare it in `Package.swift`:

```swift
.package(
    url: "https://github.com/slowbrewedmacchiato/SBAppPortfolio.git",
    from: "1.1.0"
)
```

Add one product to the consuming target:

- `SBAppPortfolio` for the packaged UI; Core is linked transitively.
- `SBAppPortfolioCore` for a custom interface without the UI resources.

## Packaged SwiftUI sheet

Define the studio catalog, identify the current app, and present the sheet:

```swift
import SBAppPortfolio
import SwiftUI

struct SettingsView: View {
    @State private var showsPortfolio = false

    var body: some View {
        Button("More From Us") {
            showsPortfolio = true
        }
        .sheet(isPresented: $showsPortfolio) {
            SBAppPortfolioView(
                configuration: SBAppPortfolioConfiguration(
                    studioApps: [
                        SBAppReference(
                            appID: "1234567890",
                            fallbackName: "My First App",
                            fallbackDescription: "A carefully written product summary."
                        ),
                        SBAppReference(
                            appID: "0987654321",
                            fallbackName: "My Second App",
                            fallbackDescription: "Useful even while the device is offline."
                        )
                    ],
                    currentAppID: "1234567890",
                    developerPageURL: URL(
                        string: "https://apps.apple.com/developer/id000000000"
                    )!
                )
            )
        }
    }
}
```

The default `SBAppPortfolioPresentation.standard` preserves the original sheet: it excludes the current app, sorts alphabetically, shows price, genre, Done, and developer-page rows, and derives a short description when Apple omits the subtitle.

Configure only the policy your host owns:

```swift
SBAppPortfolioView(
    configuration: configuration,
    presentation: SBAppPortfolioPresentation(
        currentAppBehavior: .include,
        ordering: .catalog,
        summaryPolicy: .appStoreSubtitleThenFallback,
        showsDoneButton: false,
        showsDeveloperLink: false,
        showsPrice: false,
        showsGenre: true,
        navigationTitle: "Our Apps",
        sectionTitle: "Made by Our Studio",
        sectionFooter: ""
    ),
    onOpenApp: { item in
        // Optional host-owned routing, analytics, or cross-promotion.
        // When omitted, the package opens item.appStoreURL.
    }
)
```

`SBAppPortfolioItem` merges every static reference with optional Store metadata, so a missing result or network failure never removes the host’s fallback row. `SBAppPortfolioRowView` is public for hosts that want the resolved package row inside their own composition.

Slow Brewed apps can use the built-in catalog and developer page:

```swift
SBAppPortfolioView(
    configuration: .slowBrewed(currentAppID: "your-app-id")
)
```

## Custom UI with SBAppPortfolioCore

Core accepts raw App Store IDs and does not exclude the current app, hide unreleased products, sort a catalog, or choose fallback copy. Those policies remain in the host:

```swift
import Foundation
import SBAppPortfolioCore

let references = [
    SBAppReference(
        appID: "1234567890",
        fallbackName: "My First App",
        fallbackDescription: "Curated copy owned by the host."
    ),
    SBAppReference(
        appID: "0987654321",
        fallbackName: "My Second App",
        fallbackDescription: "The complete offline fallback."
    )
]

let service = SBAppStoreLookupService()
let result = try await service.fetchApps(
    for: SBAppLookupRequest(
        appIDs: references.map(\.appID),
        countryCode: "de",
        ordering: .caller
    )
)

let metadataByID = Dictionary(
    uniqueKeysWithValues: result.apps.map { (String($0.trackId), $0) }
)

func nonempty(_ value: String?) -> String? {
    let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed?.isEmpty == false ? trimmed : nil
}

let rows = references.map { reference in
    let storeApp = metadataByID[reference.appID]
    return (
        name: nonempty(storeApp?.trackCensoredName)
            ?? nonempty(storeApp?.trackName)
            ?? reference.fallbackName,
        summary: nonempty(storeApp?.subtitle)
            ?? reference.fallbackDescription,
        artworkURL: storeApp?.bestArtworkURL,
        destinationURL: storeApp?.appStoreURL
    )
}
```

The example app contains a complete host-owned implementation in `CorePortfolioDemoView`.

### Subtitle and fallback policy

The iTunes Lookup API frequently omits the App Store subtitle. For intentional product copy, read the raw optional `subtitle` and keep the host’s curated description when it is nil or empty. `displaySubtitle` is a convenience that may derive text from the long Store description; do not use it when preserving curated copy matters.

### Artwork and destinations

- `bestArtworkURL` prefers `artworkUrl512` and falls back to `artworkUrl100`.
- `artworkURL` remains the original 100-pixel compatibility accessor.
- `appStoreURL` parses Apple’s current `trackViewUrl`.

## Lookup contract

`SBAppStoreLookupService` performs one request for all IDs and filters the response to the requested set.

- IDs are trimmed and de-duplicated by first occurrence.
- Country codes are trimmed, lowercased, and validated as two ASCII letters.
- `.caller` preserves the normalized input order (`.input` is an alias).
- `.displayName` sorts resolved results by name.
- `.response` preserves Apple’s response order.
- Unexpected and duplicate response entries are discarded.
- `missingAppIDs` reports requested IDs that Apple did not return, in caller order.
- `source` distinguishes `.network`, `.freshCache`, and `.staleCache`.

The public `SBAppStoreLookupClient` protocol makes the lookup injectable in previews and tests. `SBAppStoreApp` and `SBAppLookupResult` have public initializers for fixtures.

## Cache, refresh, and cancellation

`SBAppLookupCachePolicy.standard` keeps decoded metadata for one hour and permits stale metadata when a refresh fails. Supply a custom policy or `.disabled` when needed:

```swift
let service = SBAppStoreLookupService(
    cachePolicy: SBAppLookupCachePolicy(
        timeToLive: 15 * 60,
        allowsStaleDataOnError: true
    )
)
```

The default shared URL session uses a process-wide decoded cache. A custom `URLSession` receives an isolated decoded cache so test or authenticated traffic cannot contaminate other clients. Core bypasses `URLCache` after its decoded cache misses.

Use targeted invalidation for one normalized request and `clearCache()` only when every entry should be evicted:

```swift
try await service.invalidateCache(for: request)
let refreshed = try await service.fetchApps(for: request)
```

Invalidation generations prevent an older in-flight response from repopulating an entry that was just removed. Cancellation stops the back-deployed URLSession task and surfaces `SBAppPortfolioError.requestCancelled`; cancellation never falls back to stale data.

## Storefront

The default storefront is `us`. Pass the device’s storefront or another two-letter country code for localized Store metadata and prices. You can obtain it with StoreKit 2 (`await Storefront.current?.countryCode`) or StoreKit 1 (`SKPaymentQueue.default().storefront?.countryCode`). SBAppPortfolio does not depend on StoreKit.

## Theming and localization

The packaged sheet uses semantic SwiftUI colors and SF Symbols, and inherits the host’s `tint`. Its `Localizable.xcstrings` currently covers en, de, es, fr, ja, ko, pt-BR, and zh-Hans. Core contains no UI resources; custom interfaces own their visible fallback and error copy.

## Documentation and development

- [Getting Started](Docs/GettingStarted.md)
- [SBAppPortfolio UI API reference](https://slowbrewedmacchiato.github.io/SBAppPortfolio/documentation/sbappportfolio)
- [SBAppPortfolioCore API reference](https://slowbrewedmacchiato.github.io/SBAppPortfolio/core/documentation/sbappportfoliocore)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

Run the complete package tests with:

```bash
swift test
```

Preview both DocC sites locally:

```bash
SBAPP_PORTFOLIO_DEVELOPMENT=1 swift package generate-documentation --target SBAppPortfolio
SBAPP_PORTFOLIO_DEVELOPMENT=1 swift package generate-documentation --target SBAppPortfolioCore
```

The DocC plugin is gated behind `SBAPP_PORTFOLIO_DEVELOPMENT`, so it does not propagate into consumer package graphs.

## License

MIT. See [`LICENSE`](LICENSE).
