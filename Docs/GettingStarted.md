# Getting Started

`SBAppPortfolio` renders a "More From Us" sheet that shows your studio's other apps with live App Store metadata. This guide covers the three-line integration, custom catalogs, and storefront configuration.

## Requirements

- iOS 18.0+ / macOS 13.0+
- Swift 6.0+

## Add the package

Add `SBAppPortfolio` as a package dependency in Xcode (File ▸ Add Package Dependencies…) pointing at the repository, or in your `Package.swift`:

```swift
.package(url: "https://github.com/slowbrewed/SBAppPortfolio.git", from: "1.0.0")
```

And add `SBAppPortfolio` to your target's dependencies.

## Present the sheet (custom catalog)

The simplest integration — define your studio's apps, pass the current app's ID so it's excluded, and present the sheet:

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

## Slow Brewed catalog (convenience)

If you're shipping a Slow Brewed app, use the built-in catalog and developer page URL:

```swift
SBAppPortfolioView(configuration: .slowBrewed(currentAppID: "your-app-id"))
```

`.slowBrewed(currentAppID:)` pulls in the package's built-in catalog of six Slow Brewed apps and the canonical developer page URL. Pass your app's own App Store ID so it is excluded from the displayed rows.

## Storefront

By default the package queries the US storefront (`country=us`). Pass a different ISO country code to show users their local metadata and prices:

```swift
SBAppPortfolioConfiguration(
    studioApps: [...],
    currentAppID: "your-app-id",
    developerPageURL: URL(string: "https://apps.apple.com/developer/id000000000")!,
    lookupCountry: "jp"
)
```

For automatic device-storefront detection, read `await Storefront.current?.countryCode` (StoreKit 2) — or `SKPaymentQueue.default().storefront?.countryCode` on StoreKit 1 — and pass the result. The package does not depend on StoreKit to keep its dependency surface minimal.

## Theming

The sheet renders in neutral SwiftUI — system semantic colors and SF Symbols. Apply your app's theme via standard view modifiers on `SBAppPortfolioView` (tint, accent, custom symbols). Row backgrounds use `Color(.secondarySystemGroupedBackground)` on iOS; the sheet background uses `Color(.systemGroupedBackground)`.

## Localization

The package ships `Localizable.xcstrings` with eight locales: en, de, es, fr, ja, ko, pt-BR, zh-Hans. Strings used by the sheet resolve from the package's own bundle, so no host-side string copying is needed. To add a locale, extend the package's `Localizable.xcstrings` and submit a PR.

## Testing

The package uses Swift Testing. Run:

```bash
swift test
```

Tests cover Codable parsing (with mock iTunes Lookup fixtures), configuration self-exclusion, and service error mapping (HTTP 404, decode failure, empty results).
