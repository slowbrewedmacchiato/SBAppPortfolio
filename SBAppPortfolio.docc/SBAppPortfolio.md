# ``SBAppPortfolio``

Cross-app discovery ("More From Us") sheet for iOS apps.

`SBAppPortfolio` is a Swift Package that renders a SwiftUI sheet showing your studio's other apps, with live metadata fetched from the iTunes Lookup API. Host apps configure the package with their catalog and current app ID; the package handles fetching, caching (1-hour TTL), localization, and a neutral UI the host can theme.

## Overview

The package ships:

- A configurable studio catalog — supply your own via ``SBAppPortfolioConfiguration/studioApps``, or use the built-in ``SBStudioApps/slowBrewed`` if you're a Slow Brewed app.
- Runtime self-exclusion via ``SBAppPortfolioConfiguration/currentAppID`` — no per-app hand-maintained omission lists.
- Configurable storefront (``SBAppPortfolioConfiguration/lookupCountry``) so users in CN/JP/etc. see localized metadata and prices.
- Bundled `Localizable.xcstrings` with eight locales: en, de, es, fr, ja, ko, pt-BR, zh-Hans.
- A single batched lookup request (comma-separated App Store IDs), a module-level actor-backed cache with a 1-hour TTL, and Swift Testing tests with mock fixtures.

## Getting Started

Integrate in three lines:

```swift
.sheet(isPresented: $showPortfolio) {
    SBAppPortfolioView(
        configuration: SBAppPortfolioConfiguration(
            studioApps: [...],
            currentAppID: "your-app-id",
            developerPageURL: URL(string: "https://apps.apple.com/developer/id000000000")!
        )
    )
}
```

For the full integration guide, see <doc:GettingStarted>.
