// swift-tools-version: 6.0
//  Package.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Foundation
import PackageDescription

// `swift-docc-plugin` is a development-only dependency, gated behind an
// environment variable so it does not propagate into the package graphs of
// consuming apps. Maintainers run:
//
//   SBAPP_PORTFOLIO_DEVELOPMENT=1 swift package generate-documentation
//
// Consumers never resolve the plugin unless they opt in with the same env var.
private let isDevelopment = ProcessInfo.processInfo.environment["SBAPP_PORTFOLIO_DEVELOPMENT"] != nil
private let dependencies: [PackageDescription.Package.Dependency] = isDevelopment
    ? [.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")]
    : []

let package = Package(
    name: "SBAppPortfolio",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .macOS(.v13)
    ],
    products: [
        .library(name: "SBAppPortfolio", targets: ["SBAppPortfolio"])
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "SBAppPortfolio",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SBAppPortfolioTests",
            dependencies: ["SBAppPortfolio"],
            resources: [
                .process("Fixtures")
            ]
        )
    ]
)
