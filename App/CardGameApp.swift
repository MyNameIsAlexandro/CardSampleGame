/// Файл: App/CardGameApp.swift
/// Назначение: Содержит реализацию файла CardGameApp.swift.
/// Зона ответственности: Изолирован логикой уровня инициализации и навигации приложения.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import SwiftUI
import TwilightEngine
import CoreHeroesContent
import TwilightMarchesActIContent

@main
struct CardGameApp: App {
    @StateObject private var contentLoader = ContentLoader()

    var body: some Scene {
        WindowGroup {
            if contentLoader.isLoaded, let services = contentLoader.services {
                ContentView(services: services)
            } else {
                LoadingView(loader: contentLoader)
            }
        }
    }
}

// MARK: - Content Loader (Binary Pack Loading)

/// Represents a content item being loaded
struct LoadingItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    var count: Int?
    var status: LoadingItemStatus

    enum LoadingItemStatus {
        case pending
        case loading
        case loaded
        case failed
    }
}

/// Loads binary .pack files
/// Simple, fast loading - no caching needed (binary format is already optimized)
@MainActor
class ContentLoader: ObservableObject {
    @Published var isLoaded = false
    @Published private(set) var services: AppServices?
    @Published var loadingProgress: Double = 0
    @Published var loadingMessage = L10n.loadingDefault.localized
    @Published var loadingItems: [LoadingItem] = []
    @Published var loadingSummary: String = ""

    private let registry = ContentRegistry()
    private let localizationManager = LocalizationManager()
    private let rng = WorldRNG()
    private let safeAccess: SafeContentAccess

    private static var isVerboseLoggingEnabled: Bool {
        #if DEBUG
        guard let rawValue = ProcessInfo.processInfo.environment["TWILIGHT_TEST_VERBOSE"]?.lowercased() else {
            return false
        }
        return rawValue == "1" || rawValue == "true" || rawValue == "yes" || rawValue == "on"
        #else
        return false
        #endif
    }

    private func verboseLog(_ message: @autoclosure () -> String) {
        #if DEBUG
        guard Self.isVerboseLoggingEnabled else {
            return
        }
        print(message())
        #endif
    }

    init() {
        self.safeAccess = SafeContentAccess(registry: registry)
        Task {
            await loadContentPacks()
        }
    }

    private func loadContentPacks() async {
        loadingMessage = L10n.loadingSearchPacks.localized
        loadingProgress = 0.1

        let packURLs = findPackURLs()

        guard !packURLs.isEmpty else {
            loadingMessage = L10n.loadingContentNotFound.localized
            verboseLog("⚠️ No .pack files found")
            finishLoading()
            return
        }

        // Load .pack files
        loadingMessage = L10n.loadingContent.localized
        loadingProgress = 0.3
        initializeLoadingItems()

        await loadBinaryPacks(urls: packURLs)

        finishLoading()
    }

    private func loadBinaryPacks(urls: [URL]) async {
        do {
            let packs = try registry.loadPacks(from: urls)
            loadingProgress = 0.8

            let inventory = registry.totalInventory

            updateLoadingItem(name: L10n.loadingItemRegions.localized, status: .loaded, count: inventory.regionCount)
            updateLoadingItem(name: L10n.loadingItemEvents.localized, status: .loaded, count: inventory.eventCount)
            updateLoadingItem(name: L10n.loadingItemQuests.localized, status: .loaded, count: inventory.questCount)
            updateLoadingItem(name: L10n.loadingItemAnchors.localized, status: .loaded, count: inventory.anchorCount)
            updateLoadingItem(name: L10n.loadingItemHeroes.localized, status: .loaded, count: inventory.heroCount)
            updateLoadingItem(name: L10n.loadingItemCards.localized, status: .loaded, count: inventory.cardCount)
            updateLoadingItem(name: L10n.loadingItemEnemies.localized, status: .loaded, count: inventory.enemyCount)
            updateLoadingItem(name: L10n.loadingItemLocalization.localized, status: .loaded, count: inventory.supportedLocales.count)

            // Validate content after loading (defensive programming)
            loadingProgress = 0.85
            let validation = safeAccess.validateAllContent()

            if !validation.errors.isEmpty {
                verboseLog("⚠️ Content validation errors:")
                for error in validation.errors {
                    verboseLog("  - \(error)")
                }
            }
            if !validation.warnings.isEmpty {
                verboseLog("ℹ️ Content validation warnings:")
                for warning in validation.warnings {
                    verboseLog("  - \(warning)")
                }
            }

            loadingProgress = 0.9
            loadingMessage = L10n.loadingContentLoaded.localized

            let totalItems = inventory.regionCount + inventory.eventCount + inventory.questCount +
                             inventory.heroCount + inventory.cardCount + inventory.enemyCount
            loadingSummary = String(format: L10n.loadingSummary.localized, totalItems)

            verboseLog("ContentLoader: Loaded \(packs.count) packs:")
            for pack in packs {
                verboseLog("  - \(pack.manifest.packId) (\(pack.manifest.packType.rawValue))")
            }
            verboseLog("ContentLoader: Validation \(validation.isValid ? "passed" : "failed with \(validation.errors.count) errors")")

        } catch {
            loadingMessage = L10n.loadingError.localized
            for i in loadingItems.indices {
                loadingItems[i].status = .failed
            }
            verboseLog("ContentLoader: Failed to load packs: \(error)")
        }
    }

    // MARK: - Helpers

    private func findPackURLs() -> [URL] {
        var urls: [URL] = []

        // Load character pack (CoreHeroes)
        if let heroesURL = CoreHeroesContent.packURL {
            urls.append(heroesURL)
            verboseLog("🔍 CoreHeroes pack: \(heroesURL)")
        }

        // Load story pack (TwilightMarchesActI)
        if let storyURL = TwilightMarchesActIContent.packURL {
            urls.append(storyURL)
            verboseLog("🔍 TwilightMarchesActI pack: \(storyURL)")
        }

        verboseLog("🔍 Found \(urls.count) content packs")

        return urls
    }

    private func initializeLoadingItems() {
        loadingItems = [
            LoadingItem(name: L10n.loadingItemRegions.localized, icon: "map", status: .pending),
            LoadingItem(name: L10n.loadingItemEvents.localized, icon: "sparkles", status: .pending),
            LoadingItem(name: L10n.loadingItemQuests.localized, icon: "scroll", status: .pending),
            LoadingItem(name: L10n.loadingItemAnchors.localized, icon: "mappin.and.ellipse", status: .pending),
            LoadingItem(name: L10n.loadingItemHeroes.localized, icon: "person.fill", status: .pending),
            LoadingItem(name: L10n.loadingItemCards.localized, icon: "rectangle.portrait.on.rectangle.portrait", status: .pending),
            LoadingItem(name: L10n.loadingItemEnemies.localized, icon: "flame", status: .pending),
            LoadingItem(name: L10n.loadingItemLocalization.localized, icon: "globe", status: .pending)
        ]
    }

    private func updateLoadingItem(name: String, status: LoadingItem.LoadingItemStatus, count: Int? = nil) {
        if let index = loadingItems.firstIndex(where: { $0.name == name }) {
            loadingItems[index].status = status
            if let count = count {
                loadingItems[index].count = count
            }
        }
    }

    private func finishLoading() {
        loadingProgress = 1.0
        loadingMessage = L10n.loadingReady.localized

        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if services == nil {
                services = AppServices(
                    rng: rng,
                    registry: registry,
                    localizationManager: localizationManager
                )
            }
            isLoaded = true
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    @ObservedObject var loader: ContentLoader

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.appTitle.localized)
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView(value: loader.loadingProgress)
                .progressViewStyle(.linear)
                .frame(width: 280)

            Text(loader.loadingMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Show loading items
            if !loader.loadingItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(loader.loadingItems) { item in
                        LoadingItemRow(item: item)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }

            // Show summary when loaded
            if !loader.loadingSummary.isEmpty {
                Text(loader.loadingSummary)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
    }
}

// MARK: - Loading Item Row

struct LoadingItemRow: View {
    let item: LoadingItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .foregroundColor(iconColor)
                .frame(width: 20)

            Text(item.name)
                .font(.caption)
                .foregroundColor(.primary)

            Spacer()

            if let count = item.count {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            statusIcon
        }
    }

    private var iconColor: Color {
        switch item.status {
        case .pending: return .gray
        case .loading: return .blue
        case .loaded: return .green
        case .failed: return .red
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .pending:
            Image(systemName: "circle")
                .foregroundColor(.gray)
                .font(.caption2)
        case .loading:
            ProgressView()
                .scaleEffect(0.7)
        case .loaded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
        }
    }
}
