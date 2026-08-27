# Presenting the Packaged Portfolio

Use the `SBAppPortfolio` product when the package should resolve static and live data and render the portfolio surface.

## Preserve complete fallback rows

Every studio entry starts as an ``SBAppReference`` with an App Store ID, fallback name, and fallback description. ``SBAppPortfolioView`` merges optional live metadata by ID into an ``SBAppPortfolioItem``; missing IDs and network failures therefore leave the complete static list visible.

The standard presentation preserves version 1.0 behavior. It excludes the current app, sorts by the resolved name, derives a short Store-description summary when Apple omits the subtitle, and shows price, genre, Done, and developer-page controls.

## Configure presentation policy

```swift
let presentation = SBAppPortfolioPresentation(
    currentAppBehavior: .include,
    ordering: .catalog,
    summaryPolicy: .appStoreSubtitleThenFallback,
    showsDoneButton: false,
    showsDeveloperLink: false,
    showsPrice: false,
    showsGenre: true,
    navigationTitle: "Our Apps",
    sectionTitle: "From the Same Team",
    sectionFooter: ""
)

SBAppPortfolioView(
    configuration: configuration,
    presentation: presentation,
    onOpenApp: { item in
        routeToProduct(item)
    }
)
```

When `onOpenApp` is nil, the package opens ``SBAppPortfolioItem/appStoreURL``. Supplying the closure transfers routing to the host, which can add analytics or choose another destination without coupling SBAppPortfolio to host-specific SDKs.

Summary policies:

- ``SBAppPortfolioPresentation/SummaryPolicy/appStoreSubtitleThenDescription`` uses a nonempty raw subtitle, then a short description-derived summary, then fallback copy.
- ``SBAppPortfolioPresentation/SummaryPolicy/appStoreSubtitleThenFallback`` uses a nonempty raw subtitle, then curated fallback copy.
- ``SBAppPortfolioPresentation/SummaryPolicy/fallbackOnly`` always uses the static description.

## Compose reusable UI pieces

``SBAppPortfolioRowView`` is public for hosts that want package styling inside their own list:

```swift
SBAppPortfolioRowView(
    item: item,
    showsPrice: false,
    showsGenre: true,
    onOpen: { open(item) }
)
```

The resolved item uses ``SBAppStoreApp/bestArtworkURL``, so the packaged row prefers 512-pixel artwork and falls back to 100 pixels.

Use ``SBAppPortfolioActionPill`` when the host owns its row but wants the same tint-aware GET or price capsule:

```swift
Button(action: openApp) {
    SBAppPortfolioActionPill()
}

Button(action: buyPaidApp) {
    SBAppPortfolioActionPill(title: "$1.99")
}
```

The pill owns presentation only. The surrounding button continues to own routing, analytics, and accessibility context.

## Platform and localization boundary

The complete packaged sheet and row are supported on iOS 18 and macOS 13 or newer. The action pill also supports iOS 16, macOS 11, and visionOS 1. Visible strings resolve from the package’s resource bundle and semantic SwiftUI styling inherits the host’s tint.

For older platform floors or a design-system-owned view, use the Foundation-only Core product instead.
