//  SBAppPortfolioView.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The "More From Us" sheet. Presents a studio catalog with live App Store
/// metadata, loading skeletons, a resilient fallback state, and a footer link
/// to the developer's App Store page. It renders in neutral SwiftUI, so the
/// host can apply its own theme through standard view modifiers.
///
/// The default presentation preserves the original package UI. Advanced hosts
/// can configure its chrome and row metadata, inject opening behavior, or
/// import `SBAppPortfolioCore` and build a completely custom surface.
@available(iOS 18.0, macOS 13.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
public struct SBAppPortfolioView: View {
    private let configuration: SBAppPortfolioConfiguration
    private let presentation: SBAppPortfolioPresentation
    private let service: SBAppStoreLookupService
    private let onOpenApp: ((SBAppPortfolioItem) -> Void)?

    @State private var viewState: ViewState = .loading
    @State private var refreshFailed = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private enum ViewState {
        case loading
        case loaded([SBAppPortfolioItem])

        var isLoaded: Bool {
            if case .loaded = self { return true }
            return false
        }
    }

    public init(
        configuration: SBAppPortfolioConfiguration,
        presentation: SBAppPortfolioPresentation = .standard,
        onOpenApp: ((SBAppPortfolioItem) -> Void)? = nil
    ) {
        self.configuration = configuration
        self.presentation = presentation
        self.service = SBAppStoreLookupService(urlSession: configuration.urlSession)
        self.onOpenApp = onOpenApp
    }

    public var body: some View {
        NavigationStack {
            List {
                showcaseSection
                developerLinkSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.portfolioSheetBackground)
            .navigationTitle(navigationTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if presentation.showsDoneButton {
                    ToolbarItem(placement: .primaryAction) {
                        Button(
                            String(
                                localized: "Done",
                                bundle: .module,
                                comment: "Portfolio sheet close button."
                            )
                        ) {
                            dismiss()
                        }
                    }
                }
            }
            .presentationDragIndicator(.visible)
            .task { await loadApps() }
            .refreshable { await refreshApps() }
        }
    }

    @ViewBuilder
    private var showcaseSection: some View {
        Section {
            switch viewState {
            case .loading:
                ForEach(0..<2, id: \.self) { _ in
                    SBAppPortfolioRowLoadingView()
                }
            case .loaded(let items):
                if items.isEmpty {
                    emptyView
                } else {
                    if refreshFailed {
                        refreshFailedBanner
                    }
                    ForEach(items) { item in
                        SBAppPortfolioRowView(
                            item: item,
                            showsPrice: presentation.showsPrice,
                            showsGenre: presentation.showsGenre,
                            onOpen: { open(item) }
                        )
                    }
                }
            }
        } header: {
            Text(sectionTitle)
        } footer: {
            if case .loaded(let items) = viewState, !items.isEmpty {
                Text(sectionFooter)
            }
        }
    }

    @ViewBuilder
    private var refreshFailedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.secondary)
            Text(
                String(
                    localized: "Couldn't refresh. Showing your last saved apps.",
                    bundle: .module,
                    comment: "Portfolio refresh-failure banner shown while cached or fallback app details remain visible."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(
                String(
                    localized: "Retry",
                    bundle: .module,
                    comment: "Portfolio refresh-failure banner retry button."
                )
            ) {
                Task { await refreshApps() }
            }
            .font(.caption.weight(.medium))
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.portfolioRowBackground)
    }

    @ViewBuilder
    private var developerLinkSection: some View {
        if presentation.showsDeveloperLink {
            Section {
                Button {
                    openURL(configuration.developerPageURL)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(
                                String(
                                    localized: "View All Our Apps",
                                    bundle: .module,
                                    comment: "Portfolio developer page button title."
                                )
                            )
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                            Text(
                                String(
                                    localized: "Browse our complete collection on the App Store",
                                    bundle: .module,
                                    comment: "Portfolio developer page button subtitle."
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.portfolioRowBackground)
            }
        }
    }

    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "apps.iphone")
                .font(.title)
                .foregroundStyle(.secondary)

            Text(
                String(
                    localized: "No apps available",
                    bundle: .module,
                    comment: "Portfolio empty state title."
                )
            )
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)

            Text(
                String(
                    localized: "Our apps will appear here when available.",
                    bundle: .module,
                    comment: "Portfolio empty state message."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding()
        .listRowBackground(Color.portfolioRowBackground)
    }

    private var references: [SBAppReference] {
        switch presentation.currentAppBehavior {
        case .exclude:
            configuration.visibleApps
        case .include:
            configuration.studioApps
        }
    }

    private var request: SBAppLookupRequest {
        SBAppLookupRequest(
            appIDs: references.map(\.appID),
            countryCode: configuration.lookupCountry,
            ordering: .caller
        )
    }

    private var navigationTitle: String {
        presentation.navigationTitle
            ?? String(
                localized: "More From Us",
                bundle: .module,
                comment: "Portfolio sheet title."
            )
    }

    private var sectionTitle: String {
        presentation.sectionTitle
            ?? String(
                localized: "Our Apps",
                bundle: .module,
                comment: "Portfolio section header."
            )
    }

    private var sectionFooter: String {
        presentation.sectionFooter
            ?? String(
                localized: "Discover our other apps",
                bundle: .module,
                comment: "Portfolio section footer."
            )
    }

    private func loadApps() async {
        if !viewState.isLoaded { viewState = .loading }
        guard !references.isEmpty else {
            viewState = .loaded([])
            refreshFailed = false
            return
        }

        do {
            let result = try await service.fetchApps(for: request)
            viewState = .loaded(resolvedItems(using: result))
            refreshFailed = result.source == .staleCache
        } catch SBAppPortfolioError.requestCancelled {
            // View-driven cancellation is expected when the sheet dismisses.
        } catch {
            viewState = .loaded(resolvedItems(using: nil))
            refreshFailed = true
        }
    }

    private func refreshApps() async {
        try? await service.invalidateCache(for: request)
        await loadApps()
    }

    private func resolvedItems(using result: SBAppLookupResult?) -> [SBAppPortfolioItem] {
        let appsByID = Dictionary(
            uniqueKeysWithValues: (result?.apps ?? []).map { (String($0.trackId), $0) }
        )
        let items = references.map { reference in
            SBAppPortfolioItem(
                reference: reference,
                storeApp: appsByID[reference.appID],
                summaryPolicy: presentation.summaryPolicy
            )
        }

        switch presentation.ordering {
        case .catalog:
            return items
        case .alphabetical:
            return items.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private func open(_ item: SBAppPortfolioItem) {
        if let onOpenApp {
            onOpenApp(item)
        } else if let url = item.appStoreURL {
            openURL(url)
        }
    }
}
