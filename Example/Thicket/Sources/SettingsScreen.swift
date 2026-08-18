//  SettingsScreen.swift
//  Thicket
//
//  Created by Slow Brewed Studio on 2026-08-18.

import SwiftUI
import SBAppPortfolio

/// A stand-in settings screen showing where "More From Us" belongs in a real
/// app: below the app's own settings, above the version row.
struct SettingsScreen: View {
    @Binding var appearance: Appearance
    @Environment(\.colorScheme) private var scheme

    @State private var presentedPortfolio: PortfolioKind?
    @State private var remindersOn = true

    /// Which catalog the sheet should show. A single `sheet(item:)` drives both
    /// rows — stacking two `sheet(isPresented:)` modifiers on one view does not
    /// work in SwiftUI, since only the last one registers.
    enum PortfolioKind: String, Identifiable {
        case custom
        case slowBrewed

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    appearanceCard
                    preferencesCard
                    moreFromUsCard
                    versionFooter
                }
                .padding(20)
            }
            .background(ThicketPalette.background(for: scheme))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .tint(ThicketPalette.moss(for: scheme))
        // The package renders neutrally, so the host's `tint` flows into the
        // sheet and it picks up Thicket's moss accent without any theming API.
        .sheet(item: $presentedPortfolio) { kind in
            switch kind {
            case .custom:
                SBAppPortfolioView(configuration: .thicket)
                    .tint(ThicketPalette.moss(for: scheme))
            case .slowBrewed:
                SBAppPortfolioView(configuration: .slowBrewed(currentAppID: Self.thicketAppID))
                    .tint(ThicketPalette.moss(for: scheme))
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ThicketPalette.moss(for: scheme).gradient)
                .frame(width: 76, height: 76)
                .overlay {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white)
                }

            Text("Thicket")
                .roundedFont(.title2, weight: .semibold)

            Text("A quiet place for your notes.")
                .roundedFont(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var appearanceCard: some View {
        ThicketCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance")
                    .roundedFont(.footnote, weight: .semibold)
                    .foregroundStyle(.secondary)

                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
        }
    }

    private var preferencesCard: some View {
        ThicketCard {
            Toggle(isOn: $remindersOn) {
                Label {
                    Text("Daily reminder")
                        .roundedFont(.body)
                } icon: {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(ThicketPalette.rust(for: scheme))
                }
            }
            .tint(ThicketPalette.moss(for: scheme))
            .padding(16)
        }
    }

    private var moreFromUsCard: some View {
        ThicketCard {
            VStack(spacing: 0) {
                portfolioRow(
                    title: "More From Us",
                    subtitle: "Custom catalog, built with the general API",
                    symbol: "square.grid.2x2.fill"
                ) { presentedPortfolio = .custom }

                Divider()
                    .overlay(ThicketPalette.hairline(for: scheme))
                    .padding(.leading, 56)

                portfolioRow(
                    title: "More From Slow Brewed",
                    subtitle: "Built-in catalog, integrated in one line",
                    symbol: "cup.and.saucer.fill"
                ) { presentedPortfolio = .slowBrewed }
            }
        }
    }

    private func portfolioRow(
        title: String,
        subtitle: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 28)
                    .foregroundStyle(ThicketPalette.moss(for: scheme))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .roundedFont(.body, weight: .medium)
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .roundedFont(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var versionFooter: some View {
        Text("Thicket 1.0 · Example app for SBAppPortfolio")
            .roundedFont(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    /// Thicket is fictional, so this ID matches nothing in the catalog and every
    /// real app stays visible. A shipping app passes its own App Store ID here
    /// and the package filters it out automatically.
    static let thicketAppID = "0000000000"
}

// MARK: - Configuration

extension SBAppPortfolioConfiguration {
    /// The general-purpose path: any studio supplies its own catalog. The App
    /// Store IDs below are real so the sheet renders live metadata — placeholder
    /// IDs would return no results and the sheet would show its empty state.
    static var thicket: SBAppPortfolioConfiguration {
        SBAppPortfolioConfiguration(
            studioApps: [
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
                )
            ],
            currentAppID: SettingsScreen.thicketAppID,
            developerPageURL: URL(string: "https://apps.apple.com/developer/id1609899925")!
        )
    }
}

#Preview {
    SettingsScreen(appearance: .constant(.system))
}
