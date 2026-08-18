# SBAppPortfolio

A SwiftUI "More From Us" sheet for iOS apps. Shows your studio's other apps with live App Store metadata — fetched from the iTunes Lookup API, cached for one hour, and rendered in a neutral, themeable UI.

Built for indie developers who ship multiple apps and want a drop-in cross-sell surface without rebuilding the same sheet in every project.

## Requirements

- iOS 18.0+ / macOS 13.0+ (macOS only for local development and testing)
- Swift 6.0+
- Xcode 16+

## Installation

Add the package as a dependency in Xcode (File ▸ Add Package Dependencies…) or in your `Package.swift`:

```swift
.package(url: "https://github.com/slowbrewed/SBAppPortfolio.git", from: "1.0.0")
```

Add `SBAppPortfolio` to your target's dependencies.

## Quick start

Define your studio's apps, pass the current app's ID so it's excluded from the list, and present the sheet:

```swift
import SBAppPortfolio
import SwiftUI

struct SettingsView: View {
    @State private var showPortfolio = false

    var body: some View {
        Button("More From Us") { showPortfolio = true }
            .sheet(isPresented: $showPortfolio) {
                SBAppPortfolioView(
                    configuration: SBAppPortfolioConfiguration(
                        studioApps: [
                            SBAppReference(appID: "1234567890", fallbackName: "My First App", fallbackDescription: "A great app."),
                            SBAppReference(appID: "0987654321", fallbackName: "My Second App", fallbackDescription: "Another great app.")
                        ],
                        currentAppID: "1234567890",
                        developerPageURL: URL(string: "https://apps.apple.com/developer/id000000000")!
                    )
                )
            }
    }
}
```

The sheet fetches live metadata (icon, name, subtitle, price, genre) for every app in a single batched iTunes Lookup request, caches the results for one hour, and renders a neutral SwiftUI list. A pull-to-refresh clears the cache and re-fetches. A "View All Our Apps" footer links to your developer page.

## Features

- **Live App Store metadata** via the iTunes Lookup API (single batched request for all apps)
- **Runtime self-exclusion** — pass `currentAppID` and the host app is filtered out automatically; no per-app omission lists to maintain
- **Configurable storefront** — pass `lookupCountry` (ISO code) so users in non-US regions see localized metadata and prices
- **Locale-independent free-app detection** — uses the numeric `price` field, not the localized `formattedPrice` string, so the GET pill renders correctly in every storefront
- **Resilient decoding** — a malformed entry in the lookup response is dropped, not propagated; one bad sibling app doesn't blank the sheet
- **Bundled localization** — `Localizable.xcstrings` with 8 locales (en, de, es, fr, ja, ko, pt-BR, zh-Hans)
- **Neutral SwiftUI** — system semantic colors and SF Symbols; apply your own theme via standard view modifiers
- **Swift Testing** — mock JSON fixtures covering parsing, configuration, cache behavior, and error mapping

## Configuration

```swift
SBAppPortfolioConfiguration(
    studioApps: [...],          // your studio catalog
    currentAppID: "your-app-id", // excluded from the displayed list
    developerPageURL: URL(...),  // your App Store developer page
    lookupCountry: "us",         // optional; default "us"
    urlSession: .shared          // optional; inject for testing
)
```

### Slow Brewed catalog

If you're shipping a Slow Brewed app, use the built-in catalog and developer page URL:

```swift
SBAppPortfolioView(configuration: .slowBrewed(currentAppID: "your-app-id"))
```

## Storefront

By default the package queries the US storefront. Pass a different ISO country code to show users their local metadata and prices:

```swift
SBAppPortfolioConfiguration(
    studioApps: [...],
    currentAppID: "your-app-id",
    developerPageURL: URL(...),
    lookupCountry: "jp"
)
```

For automatic device-storefront detection, read `await Storefront.current?.countryCode` (StoreKit 2) — or `SKPaymentQueue.default().storefront?.countryCode` on StoreKit 1 — and pass the result. The package does not depend on StoreKit to keep its dependency surface minimal.

## Theming

The sheet renders in neutral SwiftUI — system semantic colors (`Color.primary`, `Color.secondary`, grouped-list backgrounds) and SF Symbols. Apply your app's theme via standard view modifiers on `SBAppPortfolioView`.

## Localization

The package ships `Localizable.xcstrings` with eight locales. Strings used by the sheet resolve from the package's own bundle (`bundle: .module`), so no host-side string copying is needed. To add a locale, extend the package's `Localizable.xcstrings` and submit a PR.

## Documentation

Full integration guide: [`Docs/GettingStarted.md`](Docs/GettingStarted.md)

Generate DocC documentation (maintainers):

```bash
SBAPP_PORTFOLIO_DEVELOPMENT=1 swift package generate-documentation
```

The `swift-docc-plugin` dependency is env-gated (`SBAPP_PORTFOLIO_DEVELOPMENT`) so it does not propagate into consumers' package graphs.

## License

MIT. See [`LICENSE`](LICENSE).
