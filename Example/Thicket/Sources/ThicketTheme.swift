//  ThicketTheme.swift
//  Thicket
//
//  Created by Slow Brewed Studio on 2026-08-18.

import SwiftUI

enum ThicketTheme {
    static let cornerRadius: CGFloat = 18
    static let screenPadding: CGFloat = 20
    static let cardSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let rowSpacing: CGFloat = 14
    static let copySpacing: CGFloat = 4
    static let minimumSpacer: CGFloat = 8
    static let appIconSize: CGFloat = 64
    static let appIconCornerRadius: CGFloat = 14
    static let hairlineWidth: CGFloat = 1
    static let placeholderOpacity: CGFloat = 0.14
}

enum ThicketPalette {
    /// Warm off-white in light, near-black in dark, softer than pure system grays.
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.035, green: 0.035, blue: 0.034)
            : Color(red: 0.955, green: 0.955, blue: 0.948)
    }

    /// Card surface, one step above the background.
    static func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.085, green: 0.085, blue: 0.082)
            : .white
    }

    /// Hairline separators and card strokes.
    static func hairline(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.055)
    }

    /// Primary accent, a muted moss green.
    static func moss(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.58, green: 0.64, blue: 0.48)
            : Color(red: 0.34, green: 0.40, blue: 0.27)
    }

    /// Secondary accent, a warm rust.
    static func rust(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.74, green: 0.50, blue: 0.40)
            : Color(red: 0.55, green: 0.25, blue: 0.18)
    }
}

extension View {
    /// SF Pro Rounded at a semantic text style.
    func roundedFont(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> some View {
        self
            .font(.system(style, design: .rounded))
            .fontWeight(weight)
    }
}

/// A card container matching the app's surface treatment.
struct ThicketCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(ThicketPalette.surface(for: scheme))
            .clipShape(RoundedRectangle(cornerRadius: ThicketTheme.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: ThicketTheme.cornerRadius, style: .continuous)
                    .stroke(ThicketPalette.hairline(for: scheme), lineWidth: 1)
            }
    }
}
