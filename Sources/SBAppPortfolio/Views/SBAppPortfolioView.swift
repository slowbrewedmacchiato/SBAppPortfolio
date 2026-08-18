//  SBAppPortfolioView.swift
//  SBAppPortfolio
//
//  Created by Slow Brewed Studio on 2026-08-18.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The "More From Us" sheet. Presents a studio catalog with live App Store
/// metadata, loading skeletons, an error state with retry, and a footer
/// link to the developer's App Store page. Renders in neutral SwiftUI — the
/// host can apply its own theme via standard view modifiers.
public struct SBAppPortfolioView: View {
    let configuration: SBAppPortfolioConfiguration
    let service: SBAppStoreLookupService

    @State private var viewState: ViewState = .loading
    @State private var refreshFailed: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    enum ViewState {
        case loading
        case error(String)
        case loaded([SBAppStoreApp])

        var isLoaded: Bool {
            if case .loaded = self { return true }
            return false
        }
    }

    public init(configuration: SBAppPortfolioConfiguration) {
        self.configuration = configuration
        self.service = SBAppStoreLookupService(urlSession: configuration.urlSession)
    }

    public var body: some View {
        NavigationStack {
            List {
                showcaseSection
                developerLinkSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.portfolioSheetBackground)
            .navigationTitle(String(localized: "More From Us", bundle: .module, comment: "Portfolio sheet title."))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(String(localized: "Done", bundle: .module, comment: "Portfolio sheet close button.")) {
                        dismiss()
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
            case .error(let message):
                errorView(message: message)
            case .loaded(let apps):
                if apps.isEmpty {
                    emptyView
                } else {
                    if refreshFailed {
                        refreshFailedBanner
                    }
                    ForEach(apps) { app in
                        SBAppPortfolioRowView(app: app)
                    }
                }
            }
        } header: {
            Text(String(localized: "Our Apps", bundle: .module, comment: "Portfolio section header."))
        } footer: {
            if case .loaded(let apps) = viewState, !apps.isEmpty {
                Text(String(localized: "Discover our other apps", bundle: .module, comment: "Portfolio section footer."))
            }
        }
    }

    @ViewBuilder
    private var refreshFailedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.secondary)
            Text(String(localized: "Couldn't refresh. Showing your last saved apps.", bundle: .module, comment: "Portfolio refresh-failure banner shown when a pull-to-refresh fails but stale content remains."))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Button(String(localized: "Retry", bundle: .module, comment: "Portfolio refresh-failure banner retry button.")) {
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
        Section {
            Button {
                openURL(configuration.developerPageURL)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "View All Our Apps", bundle: .module, comment: "Portfolio developer page button title."))
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(String(localized: "Browse our complete collection on the App Store", bundle: .module, comment: "Portfolio developer page button subtitle."))
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

    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.secondary)

            Text(String(localized: "Unable to load apps", bundle: .module, comment: "Portfolio error title."))
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Button(String(localized: "Try Again", bundle: .module, comment: "Portfolio retry button.")) {
                Task { await refreshApps() }
            }
            .font(.callout.weight(.medium))
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .listRowBackground(Color.portfolioRowBackground)
    }

    @ViewBuilder
    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "apps.iphone")
                .font(.title)
                .foregroundStyle(.secondary)

            Text(String(localized: "No apps available", bundle: .module, comment: "Portfolio empty state title."))
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Text(String(localized: "Our apps will appear here when available.", bundle: .module, comment: "Portfolio empty state message."))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .listRowBackground(Color.portfolioRowBackground)
    }

    private func loadApps() async {
        // Show the loading skeleton only on the first load; once loaded, keep
        // the previous content visible during refresh so the sheet does not
        // flicker back to skeletons.
        if !viewState.isLoaded { viewState = .loading }
        do {
            let apps = try await service.fetchApps(for: configuration)
            viewState = .loaded(apps)
            refreshFailed = false
        } catch SBAppPortfolioError.requestCancelled {
            // Cancellation happens when the sheet dismisses mid-fetch or a
            // newer refresh supersedes this one. Keep whatever state we had.
        } catch {
            // If we already have content, keep it on screen and surface the
            // failure as a non-blocking banner with a retry affordance. Only
            // flip to the full error screen when there is nothing to show.
            guard viewState.isLoaded else {
                viewState = .error(error.localizedDescription)
                return
            }
            refreshFailed = true
        }
    }

    private func refreshApps() async {
        await service.clearCache()
        await loadApps()
    }
}
