//  SBAppPortfolioError.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import Foundation

/// Errors surfaced by ``SBAppStoreLookupService`` while fetching App Store
/// metadata. Each case carries a user-facing localized description.
public enum SBAppPortfolioError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case networkError(String)
    case requestCancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            String(localized: "Invalid App Store URL", bundle: .module, comment: "Portfolio lookup error.")
        case .invalidResponse:
            String(localized: "Invalid response from App Store", bundle: .module, comment: "Portfolio lookup error.")
        case .httpError(let code):
            String(localized: "App Store request failed with code \(code)", bundle: .module, comment: "Portfolio lookup HTTP error.")
        case .decodingError:
            String(localized: "Failed to parse App Store data", bundle: .module, comment: "Portfolio lookup error.")
        case .networkError(let message):
            String(localized: "Network error: \(message)", bundle: .module, comment: "Portfolio lookup network error.")
        case .requestCancelled:
            String(localized: "Request was cancelled", bundle: .module, comment: "Portfolio lookup error.")
        }
    }
}
