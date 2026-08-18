//  SBAppPortfolio.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Foundation
import SwiftUI

/// Cross-app discovery ("More From Us") sheet for Slow Brewed studio apps.
///
/// Host apps configure the package with their studio catalog and current app ID,
/// then present ``SBAppPortfolioView`` in a SwiftUI sheet. The package fetches
/// live App Store metadata via the iTunes Lookup API, caches results for one
/// hour, and renders a neutral SwiftUI list that the host can theme.
public enum SBAppPortfolio {
    /// Package version string.
    public static let version = "1.0.0"
}
