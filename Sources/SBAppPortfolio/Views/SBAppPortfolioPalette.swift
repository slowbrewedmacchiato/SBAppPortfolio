//  SBAppPortfolioPalette.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import SwiftUI

/// Cross-platform color helpers so the package builds for both iOS (its
/// primary deployment target) and macOS (used for local Swift Testing).
/// On iOS these map to the grouped-list UIKit colors; on macOS they fall
/// back to semantic AppKit equivalents.
@available(iOS 18.0, macOS 13.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
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

extension Color {
    /// Fill behind the GET / price action pill, matching the App Store's
    /// neutral capsule. Pairs with tinted text supplied by the host.
    static var portfolioActionPill: Color {
        #if canImport(UIKit)
        Color(uiColor: .tertiarySystemFill)
        #elseif canImport(AppKit)
        if #available(macOS 12.0, *) {
            Color(nsColor: .quaternaryLabelColor).opacity(0.5)
        } else {
            Color.secondary.opacity(0.12)
        }
        #else
        Color.secondary.opacity(0.12)
        #endif
    }
}
