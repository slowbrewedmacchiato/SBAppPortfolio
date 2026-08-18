//  SBStudioApps.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Foundation

/// Canonical Slow Brewed studio app catalog, maintained once inside the
/// package. Host apps pass their own `currentAppID` so the package can
/// exclude itself at runtime; no per-app hand-maintained omission is needed.
public enum SBStudioApps {
    /// Slow Brewed developer page on the App Store.
    public static let developerPageURL = URL(string: "https://apps.apple.com/developer/id1609899925")!

    /// All six Slow Brewed iOS apps. The host filters out its own ID at runtime
    /// via ``SBAppPortfolioConfiguration/currentAppID``.
    public static let slowBrewed: [SBAppReference] = [
        SBAppReference(
            appID: "6781631782",
            fallbackName: "AppStead",
            fallbackDescription: "App Store Connect workspace for indie developers."
        ),
        SBAppReference(
            appID: "6755578065",
            fallbackName: "CreatorCaps",
            fallbackDescription: "Caption videos quickly on your iPhone."
        ),
        SBAppReference(
            appID: "6751930050",
            fallbackName: "Glyppo",
            fallbackDescription: "Track glucose with clarity and calm design."
        ),
        SBAppReference(
            appID: "6479405901",
            fallbackName: "Glu Sight",
            fallbackDescription: "See your glucose trends at a glance."
        ),
        SBAppReference(
            appID: "6749046071",
            fallbackName: "MIRA",
            fallbackDescription: "A thoughtful tool from Slow Brewed."
        ),
        SBAppReference(
            appID: "6760252774",
            fallbackName: "Second Draft",
            fallbackDescription: "Write and refine with a focused drafting companion."
        )
    ]
}
