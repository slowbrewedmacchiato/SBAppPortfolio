# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
