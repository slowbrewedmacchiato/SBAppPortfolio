# ``SBAppPortfolio``

A batteries-included SwiftUI portfolio and a Foundation-only App Store lookup client.

## Overview

The package separates reusable lookup mechanics from host-owned product policy:

- Add the `SBAppPortfolio` product for a localized “More From Us” sheet, static/live fallback resolution, a reusable row, and the Store action pill.
- Add the `SBAppPortfolioCore` product when the host owns catalog visibility, release state, ordering, fallback copy, routing, and UI.

The full UI product depends on Core and preserves the original source surface with explicit compatibility aliases. A target importing `SBAppPortfolio` does not also need to import or link Core.

### Packaged UI

``SBAppPortfolioView`` accepts an ``SBAppPortfolioConfiguration`` and an optional ``SBAppPortfolioPresentation``. Its default presentation excludes the current app, sorts alphabetically, and shows the localized navigation, pricing, genre, Done, and developer-page elements from version 1.0.

The view resolves every ``SBAppReference`` into an ``SBAppPortfolioItem``, retaining the static name and description whenever Apple omits an ID or lookup fails. Hosts can customize summary policy and chrome, intercept app opening, or compose the public ``SBAppPortfolioRowView`` and ``SBAppPortfolioActionPill`` themselves.

### Foundation-only Core

Core batches ``SBAppLookupRequest`` IDs into one iTunes Lookup request. It normalizes input, filters unexpected results, reports missing IDs, exposes caller/display-name/response ordering, and identifies whether metadata came from the network, fresh cache, or stale cache.

Apple frequently omits the raw `subtitle` field. A custom interface with intentional product copy should use a nonempty raw subtitle only and otherwise retain its curated ``SBAppReference/fallbackDescription``. Use ``SBAppStoreApp/bestArtworkURL`` for the 512-pixel artwork with a 100-pixel fallback.

## Getting Started

Present the standard sheet:

```swift
.sheet(isPresented: $showsPortfolio) {
    SBAppPortfolioView(
        configuration: SBAppPortfolioConfiguration(
            studioApps: references,
            currentAppID: currentAppID,
            developerPageURL: developerPageURL
        )
    )
}
```

For a completely custom interface, add only `SBAppPortfolioCore` and use ``SBAppStoreLookupClient`` to overlay metadata onto the host’s already-filtered static catalog.

## Topics

### Choose an integration

- <doc:PortfolioUI>
- <doc:CoreLookup>

### Packaged UI

- ``SBAppPortfolioView``
- ``SBAppPortfolioRowView``
- ``SBAppPortfolioActionPill``
- ``SBAppPortfolioConfiguration``
- ``SBAppPortfolioPresentation``
- ``SBAppPortfolioItem``
- ``SBAppReference``
- ``SBStudioApps``

### Core lookup

- ``SBAppStoreLookupClient``
- ``SBAppStoreLookupService``
- ``SBAppLookupRequest``
- ``SBAppLookupResult``
- ``SBAppLookupOrdering``
- ``SBAppLookupSource``
- ``SBAppLookupCachePolicy``
- ``SBAppStoreApp``
- ``SBAppPortfolioError``
