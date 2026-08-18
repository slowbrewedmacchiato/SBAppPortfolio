//  ThicketApp.swift
//  Thicket
//
//  Created by Slow Brewed Studio on 2026-08-18.

import SwiftUI

@main
struct ThicketApp: App {
    /// Lets a reviewer flip light/dark without leaving the app.
    @State private var appearance: Appearance = .system

    var body: some Scene {
        WindowGroup {
            SettingsScreen(appearance: $appearance)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
