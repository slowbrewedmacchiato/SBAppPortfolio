//  SBAppReference.swift
//  SBAppPortfolioCore
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Foundation

/// A static reference to an app in a studio catalog.
///
/// The fallback fields remain available to presentation layers when live App
/// Store metadata is missing or unavailable.
public struct SBAppReference: Sendable, Identifiable, Equatable, Hashable {
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
