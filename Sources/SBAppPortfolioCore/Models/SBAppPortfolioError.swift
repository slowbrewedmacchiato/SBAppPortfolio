//  SBAppPortfolioError.swift
//  SBAppPortfolioCore
//
//  Created by Angelo Cammalleri on 2026-08-21.

import Foundation

/// Errors surfaced while requesting App Store metadata.
public enum SBAppPortfolioError: LocalizedError, Sendable, Equatable {
    case invalidURL
    case invalidCountryCode(String)
    case invalidResponse
    case httpError(Int)
    case decodingError
    case networkError(String)
    case requestCancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid App Store URL"
        case .invalidCountryCode(let code):
            "Invalid App Store country code: \(code)"
        case .invalidResponse:
            "Invalid response from App Store"
        case .httpError(let code):
            "App Store request failed with code \(code)"
        case .decodingError:
            "Failed to parse App Store data"
        case .networkError(let message):
            "Network error: \(message)"
        case .requestCancelled:
            "Request was cancelled"
        }
    }
}
