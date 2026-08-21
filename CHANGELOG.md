# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `SBAppPortfolioCore`, a Foundation-only library product for host-owned
  catalogs and interfaces on iOS 16, macOS 11, watchOS 9, tvOS 16, and
  visionOS 1.
- Public request, result, cache-source, ordering, client, and cache-policy APIs
  for batched App Store lookup, including injectable protocols and
  fixture-friendly model initializers.
- Caller, display-name, and Apple-response ordering, stable input
  de-duplication, normalized storefront country codes, unexpected-result
  filtering, and explicit `missingAppIDs` reporting.
- `artworkUrl512` and `bestArtworkURL`, preferring high-resolution artwork
  while retaining the original 100-pixel accessor for compatibility.
- Configurable decoded-metadata caching with fresh/stale result sources,
  targeted invalidation, generation-safe in-flight responses, isolated custom
  URLSession caches, and a fully disabled policy.
- A cancellation-aware URLSession bridge that supports the Core deployment
  floors and maps cancellation to `SBAppPortfolioError.requestCancelled`.
- `SBAppPortfolioPresentation` for current-app inclusion, catalog or
  alphabetical ordering, summary fallback policy, optional sheet chrome,
  row metadata visibility, and custom section copy.
- Public `SBAppPortfolioItem` and `SBAppPortfolioRowView` seams for hosts that
  want package fallback resolution or row styling inside their own surface.
- A Core-only Thicket example that preserves host ordering and curated copy
  while overlaying live Store metadata by App Store ID.

### Changed

- The original `SBAppPortfolio` product now depends on Core while preserving
  its existing public model and service names through explicit type aliases
  and its original configuration-based fetch overload.
- The packaged view retains fallback rows when Apple omits an ID or lookup
  fails, and supports host-owned routing without depending on cross-promotion
  libraries.
- Package platform floors now match Core consumers; newer SwiftUI availability
  remains explicit on the packaged UI product.
- Lookup cache misses bypass URLSession's local response cache so targeted
  refresh reaches Apple rather than being satisfied by stale transport data.
- Documentation and CI distinguish the Core and packaged-UI adoption paths and
  verify Core at every declared minimum platform floor.

## [1.0.0] - 2026-08-18

First tagged release.

### Added

- `SBAppPortfolioView`, a SwiftUI sheet listing a studio's other apps with live
  App Store metadata: icon, name, subtitle, genre, and price.
- `SBAppPortfolioConfiguration` for supplying a catalog, the host app's App
  Store ID, a developer page URL, a storefront country, and a `URLSession`.
- Runtime self-exclusion, so the app presenting the sheet is filtered out of
  its own catalog without a hand-maintained omission list.
- `SBStudioApps.slowBrewed`, a built-in catalog and developer page for Slow
  Brewed apps, alongside the general configuration API.
- Configurable storefront via `lookupCountry`, so users outside the US see
  local metadata and prices.
- A single batched iTunes Lookup request for the whole catalog, cached in a
  module-level actor with a one-hour TTL.
- Per-element decoding, so one malformed entry in a response is dropped rather
  than failing the whole sheet.
- Locale-independent free-app detection based on the numeric `price` field
  rather than the localized `formattedPrice` string.
- Bundled `Localizable.xcstrings` resolved from the package's own bundle, so a
  host app needs no string setup.
- A non-blocking banner with a retry action when a refresh fails while content
  is already on screen.
- `Example/Thicket`, a themed example app demonstrating both configuration
  paths, light and dark, and localization.

[Unreleased]: https://github.com/slowbrewedmacchiato/SBAppPortfolio/compare/1.0.0...HEAD
[1.0.0]: https://github.com/slowbrewedmacchiato/SBAppPortfolio/releases/tag/1.0.0
