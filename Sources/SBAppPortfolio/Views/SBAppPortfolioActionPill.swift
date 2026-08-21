//  SBAppPortfolioActionPill.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Foundation
import SwiftUI

/// The App Store-style GET or price pill used by portfolio rows.
///
/// This view deliberately owns presentation only. Place it inside a `Button`
/// when the host owns routing, analytics, or other interaction behavior.
public struct SBAppPortfolioActionPill: View {
    private let title: String

    /// Creates a pill with the package-localized GET title.
    public init() {
        self.init(
            title: NSLocalizedString(
                "GET",
                tableName: nil,
                bundle: .module,
                value: "GET",
                comment: "Portfolio row action label for free apps."
            )
        )
    }

    /// Creates a pill with host-supplied text such as a formatted Store price.
    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        tintedLabel
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.portfolioActionPill))
    }

    @ViewBuilder
    private var tintedLabel: some View {
        #if os(macOS)
        if #available(macOS 12.0, *) {
            label.foregroundStyle(.tint)
        } else {
            label.foregroundColor(.accentColor)
        }
        #else
        label.foregroundStyle(.tint)
        #endif
    }

    private var label: some View {
        Text(title)
            .font(.caption.weight(.bold))
    }
}
