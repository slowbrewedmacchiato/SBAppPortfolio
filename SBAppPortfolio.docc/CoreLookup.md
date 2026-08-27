# Building a Custom Portfolio with Core

Use `SBAppPortfolioCore` when the host owns catalog visibility, release state, ordering, fallback copy, routing, and UI.

## Request only visible products

Filter the host catalog before calling Core. Core intentionally has no concept of the active app or an unreleased product.

```swift
let request = SBAppLookupRequest(
    appIDs: visibleReferences.map(\.appID),
    countryCode: "de",
    ordering: .caller
)

let client: any SBAppStoreLookupClient = SBAppStoreLookupService()
let result = try await client.fetchApps(for: request)
```

IDs are trimmed and de-duplicated by first occurrence. Country codes are trimmed, lowercased, and validated as two ASCII letters. Unexpected and duplicate response entries are discarded.

Ordering options:

- `.caller` preserves normalized input order; `.input` is an alias.
- `.displayName` sorts returned metadata by resolved name.
- `.response` preserves Apple’s response order.

``SBAppLookupResult/missingAppIDs`` reports IDs Apple did not return in caller order. ``SBAppLookupResult/source`` distinguishes network, fresh-cache, and stale-cache results.

## Merge over static policy

Map results by numeric App Store ID and then traverse the host’s static list:

```swift
let metadataByID = Dictionary(
    uniqueKeysWithValues: result.apps.map { (String($0.trackId), $0) }
)

let resolved = visibleReferences.map { reference in
    (reference, metadataByID[reference.appID])
}
```

This keeps host ordering and every static release, platform, website, review, and routing field intact.

Apple’s lookup response frequently omits ``SBAppStoreApp/subtitle``. Use the trimmed raw subtitle only when it is nonempty; otherwise retain the host’s curated fallback description. ``SBAppStoreApp/displaySubtitle`` may derive text from the long Store description and is not appropriate for that policy.

Use ``SBAppStoreApp/bestArtworkURL`` to prefer 512-pixel artwork and fall back to the original 100-pixel URL. ``SBAppStoreApp/appStoreURL`` exposes Apple’s current `trackViewUrl`.

## Cache and refresh

``SBAppLookupCachePolicy/standard`` caches decoded metadata for one hour and permits stale fallback on refresh errors. A custom policy controls both values; ``SBAppLookupCachePolicy/disabled`` performs no decoded-cache reads or writes.

The default shared URL session uses a process-wide decoded cache. Injected sessions receive isolated caches. After a decoded-cache miss, Core bypasses the transport’s local URL cache.

Invalidate only the affected request:

```swift
try await client.invalidateCache(for: request)
let refreshed = try await client.fetchApps(for: request)
```

``SBAppStoreLookupClient/clearCache()`` evicts every entry. Generation checks prevent responses already in flight from repopulating invalidated entries.

## Cancellation and errors

Cancelling the caller cancels the back-deployed URLSession task and throws ``SBAppPortfolioError/requestCancelled``. Cancellation does not return stale data.

Other network, HTTP, response, country, and decoding failures are represented by ``SBAppPortfolioError``. A host-owned portfolio should keep its complete static list visible when these errors occur.

Core is Foundation-only and supports iOS 16, macOS 11, watchOS 9, tvOS 16, and visionOS 1.
