# Getting Started

SBAppPortfolio separates App Store lookup mechanics from portfolio presentation:

- Use `SBAppPortfolio` for the localized SwiftUI sheet, fallback resolution, and optional reusable row.
- Use `SBAppPortfolioCore` when your app or shared design system owns the UI and all catalog policy.

## Requirements

| Product | Minimum platforms |
| --- | --- |
| `SBAppPortfolioCore` | iOS 16, macOS 11, watchOS 9, tvOS 16, visionOS 1 |
| `SBAppPortfolio` | iOS 18, macOS 13 |

Both products require Swift 6.0 and Xcode 16 or newer.

## Add the package

Add the repository with File ▸ Add Package Dependencies… or declare it in `Package.swift`:

```swift
.package(
    url: "https://github.com/slowbrewedmacchiato/SBAppPortfolio.git",
    from: "1.1.0"
)
```

Select `SBAppPortfolio` for the packaged UI or `SBAppPortfolioCore` for a Foundation-only client. A UI-only target does not need to add Core separately because the UI product preserves its original public names through explicit compatibility aliases. A shared target that imports Core everywhere and UI only on supported platforms may declare both products with a SwiftPM platform condition.

## Present the packaged sheet

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
                            fallbackDescription: "Curated copy for the complete fallback row."
                        ),
                        SBAppReference(
                            appID: "0987654321",
                            fallbackName: "My Second App",
                            fallbackDescription: "Shown when live metadata is unavailable."
                        )
                    ],
                    currentAppID: "1234567890",
                    developerPageURL: URL(
                        string: "https://apps.apple.com/developer/id000000000"
                    )!,
                    lookupCountry: "us"
                )
            )
        }
    }
}
```

The sheet makes one batched lookup, overlays each result onto its matching static reference, and keeps fallback rows for missing IDs or request failures. By default it excludes `currentAppID`, sorts alphabetically, and opens Apple’s current Store URL.

Slow Brewed apps can use the built-in catalog:

```swift
SBAppPortfolioView(
    configuration: .slowBrewed(currentAppID: "your-app-id")
)
```

## Configure presentation

`SBAppPortfolioPresentation.standard` preserves the original 1.0 appearance. Override only the host-owned decisions:

```swift
let presentation = SBAppPortfolioPresentation(
    currentAppBehavior: .exclude,                 // or .include
    ordering: .catalog,                           // or .alphabetical
    summaryPolicy: .appStoreSubtitleThenFallback,
    showsDoneButton: false,
    showsDeveloperLink: true,
    showsPrice: false,
    showsGenre: true,
    navigationTitle: "Our Apps",
    sectionTitle: "From the Same Team",
    sectionFooter: "More products are on the way."
)

SBAppPortfolioView(
    configuration: configuration,
    presentation: presentation,
    onOpenApp: { item in
        // Optional host routing or analytics.
        // Without this closure, the view opens item.appStoreURL.
    }
)
```

Summary policies behave as follows:

| Policy | Resolution |
| --- | --- |
| `.appStoreSubtitleThenDescription` | Raw nonempty Store subtitle, then a short description-derived summary, then the host fallback. This is the default. |
| `.appStoreSubtitleThenFallback` | Raw nonempty Store subtitle, then the host’s curated fallback. |
| `.fallbackOnly` | Always use the host’s fallback description. |

`SBAppPortfolioItem` is the resolved static/live model. `SBAppPortfolioRowView` can render it in a host-owned list while preserving package styling.

`SBAppPortfolioActionPill` is the row's presentation-only GET or price capsule. It does not open URLs or record analytics, so a host can place it inside its own button:

```swift
Button(action: openApp) {
    SBAppPortfolioActionPill()
}

Button(action: buyPaidApp) {
    SBAppPortfolioActionPill(title: "$1.99")
}
```

The pill supports iOS 16, macOS 11, and visionOS 1. The complete packaged sheet and row retain their iOS 18 and macOS 13 deployment floors.

## Build a custom interface with Core

Core deliberately does not know which app is active, released, visible, or promoted. Filter and order the static catalog first, then request exactly those IDs:

```swift
import SBAppPortfolioCore

let visibleReferences: [SBAppReference] = catalogReferences.filter { reference in
    releasedAppIDs.contains(reference.appID)
        && reference.appID != currentAppID
}

let request = SBAppLookupRequest(
    appIDs: visibleReferences.map(\.appID),
    countryCode: "de",
    ordering: .caller
)

let client: any SBAppStoreLookupClient = SBAppStoreLookupService()
let result = try await client.fetchApps(for: request)
let metadataByID = Dictionary(
    uniqueKeysWithValues: result.apps.map { (String($0.trackId), $0) }
)

let rows = visibleReferences.map { reference in
    let live = metadataByID[reference.appID]
    return (
        id: reference.appID,
        name: live?.trackCensoredName
            ?? live?.trackName
            ?? reference.fallbackName,
        subtitle: live?.subtitle,
        fallbackSummary: reference.fallbackDescription,
        artworkURL: live?.bestArtworkURL,
        appStoreURL: live?.appStoreURL
    )
}
```

Keep the static list on screen while loading and on errors. Merge by numeric App Store ID rather than trusting response order. This preserves release flags, active-app behavior, product websites, review links, routing, and every other host-owned field.

### Subtitle caveat

Apple’s iTunes Lookup response frequently has no `subtitle`, even when a subtitle is visible on the App Store page. When the product copy is intentional:

1. Read the raw optional `SBAppStoreApp.subtitle`.
2. Trim it and use it only when nonempty.
3. Otherwise retain `SBAppReference.fallbackDescription`.

`displaySubtitle` may derive text from the long Store description and is therefore unsuitable for this curated-fallback policy.

### Artwork and Store URL

Use `bestArtworkURL`; it prefers `artworkUrl512` and falls back to the legacy 100-pixel artwork. Use `appStoreURL` for Apple’s current `trackViewUrl`. Keep a bundled icon and a deterministic Store URL fallback when a complete offline experience is required.

## Understand request and result behavior

`SBAppLookupRequest` normalizes its inputs before lookup:

- IDs are trimmed, empty IDs are dropped, and duplicates keep their first position.
- The country code is trimmed and lowercased; it must be exactly two ASCII letters.
- `.caller` is the default and preserves normalized input order. `.input` is an alias.
- `.displayName` sorts the returned metadata by resolved name.
- `.response` preserves Apple’s response order.

The service filters out unexpected IDs and duplicate response entries. `SBAppLookupResult.missingAppIDs` reports requested IDs that Apple did not return, in caller order. `source` is `.network`, `.freshCache`, or `.staleCache`.

The public `SBAppStoreLookupClient` protocol and public model/result initializers support small fakes in previews and tests without performing a network request.

## Cache and refresh

The standard policy caches decoded metadata for one hour and returns stale decoded metadata if a refresh fails:

```swift
let service = SBAppStoreLookupService(
    cachePolicy: SBAppLookupCachePolicy(
        timeToLive: 30 * 60,
        allowsStaleDataOnError: true
    )
)
```

Use `.disabled` for no decoded-cache reads or writes. The default shared `URLSession` uses a process-wide decoded cache; an injected custom session receives an isolated cache.

Invalidate only the request being refreshed:

```swift
try await service.invalidateCache(for: request)
let refreshed = try await service.fetchApps(for: request)
```

`clearCache()` removes every decoded entry. Invalidation is generation-safe, so an older in-flight request cannot repopulate a removed entry. A cache miss bypasses URLSession’s local response cache before contacting Apple.

## Cancellation and errors

Core supports task cancellation on macOS 11 and the other declared platform floors. Cancelling the calling task cancels the underlying URLSession task and throws `SBAppPortfolioError.requestCancelled`. Cancellation does not return stale metadata.

The packaged SwiftUI view treats cancellation as expected lifecycle behavior. Other failures retain static rows and show a non-blocking refresh warning.

## Storefront

The default storefront is `us`. Pass another two-letter country code for localized metadata and pricing. The host can obtain a current storefront through StoreKit 2 or StoreKit 1; the package itself has no StoreKit dependency.

## Theming and localization

The packaged view uses semantic colors and SF Symbols and inherits the host’s `tint`. Visible UI strings resolve from the package resource bundle. Core has no UI resources, so a custom interface owns its fallback, error, accessibility, and action copy.

## Example and testing

`Example/Thicket` demonstrates:

- the default packaged UI;
- the Slow Brewed convenience catalog;
- configurable host-owned presentation;
- a custom interface importing only `SBAppPortfolioCore`;
- host order and curated fallback copy surviving missing network metadata.

Run all package suites:

```bash
swift test
```

CI also cross-compiles Core at each declared minimum platform floor and builds the example against both products.
