//  SBAppPortfolioPalette.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import SwiftUI

/// Cross-platform color helpers so the package builds for both iOS (its
/// primary deployment target) and macOS (used for local Swift Testing).
/// On iOS these map to the grouped-list UIKit colors; on macOS they fall
/// back to semantic AppKit equivalents.
extension Color {
    /// Row card background on a grouped list.
    static var portfolioRowBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }

    /// Sheet (List) background behind the rows.
    static var portfolioSheetBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }

    /// Hairline separator stroke.
    static var portfolioHairline: Color {
        #if canImport(UIKit)
        Color(uiColor: .separator)
        #else
        Color(nsColor: .separatorColor)
        #endif
    }
}
