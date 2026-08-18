//  SBAppReference.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Foundation

/// A static, host-provided reference to a sibling app in the studio catalog.
///
/// The host (or the package's built-in ``SBStudioApps/slowBrewed`` constant)
/// supplies an array of these via ``SBAppPortfolioConfiguration/studioApps``.
/// The reference carries enough data to render a fallback row when the
/// iTunes Lookup API fails; live metadata from ``SBAppStoreApp`` is
/// preferred whenever a fetch succeeds.
public struct SBAppReference: Sendable, Identifiable, Equatable {
    public let appID: String
    public let fallbackName: String
    public let fallbackDescription: String

    public var id: String { appID }

    public init(appID: String, fallbackName: String, fallbackDescription: String) {
        self.appID = appID
        self.fallbackName = fallbackName
        self.fallbackDescription = fallbackDescription
    }
}
