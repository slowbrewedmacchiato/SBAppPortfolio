# ``SBAppPortfolioCore``

A Foundation-only client for batched App Store lookup.

## Overview

SBAppPortfolioCore fetches raw iTunes Lookup metadata without owning catalog or presentation policy. Hosts decide which IDs are visible, which product is active, whether an app is released, how rows are ordered, what fallback copy is shown, and where selection routes.

Create an ``SBAppLookupRequest`` and call a concrete ``SBAppStoreLookupService`` or an injected ``SBAppStoreLookupClient``:

```swift
let request = SBAppLookupRequest(
    appIDs: visibleAppIDs,
    countryCode: "de",
    ordering: .caller
)

let result = try await SBAppStoreLookupService().fetchApps(for: request)
```

Merge ``SBAppLookupResult/apps`` over the host’s static catalog by ``SBAppStoreApp/trackId``. Keep curated fallback descriptions because Apple’s lookup response frequently omits the raw ``SBAppStoreApp/subtitle``. Use ``SBAppStoreApp/bestArtworkURL`` for the best available 512- or 100-pixel artwork.

The standard cache identifies fresh and stale results, supports targeted invalidation, and honors task cancellation on every declared platform floor.

## Topics

### Request and result

- ``SBAppLookupRequest``
- ``SBAppLookupResult``
- ``SBAppLookupOrdering``
- ``SBAppLookupSource``

### Client

- ``SBAppStoreLookupClient``
- ``SBAppStoreLookupService``
- ``SBAppLookupCachePolicy``
- ``SBAppPortfolioError``

### Models

- ``SBAppStoreApp``
- ``SBAppReference``
