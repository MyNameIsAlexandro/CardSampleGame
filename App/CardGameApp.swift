import SwiftUI
import TwilightEngine
import CoreHeroesContent
import TwilightMarchesActIContent

@main
struct CardGameApp: App {
    @StateObject private var contentLoader = ContentLoader()

    var body: some Scene {
        WindowGroup {
            if contentLoader.isLoaded {
                ContentView()
            } else {
                LoadingView(loader: contentLoader)
            }
        }
    }
}

// MARK: - Content Loader (Background Thread)

/// Loading stages for progress tracking
enum LoadingStage {
    case searching
    case validatingCache
    case loadingFromCache
    case loadingFromJSON
    case savingCache
    case ready
}

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

/// Loads content packs with caching support
/// - First launch: loads from JSON, saves to cache
/// - Subsequent launches: loads from cache if valid
@MainActor
class ContentLoader: ObservableObject {
    @Published var isLoaded = false
    @Published var loadingProgress: Double = 0
    @Published var loadingMessage = L10n.loadingDefault.localized
    @Published var loadingStage: LoadingStage = .searching
    @Published var loadingItems: [LoadingItem] = []
    @Published var loadingSummary: String = ""
    @Published var isFromCache = false

    private let cache = FileSystemCache.shared

    /// Initialize loading items with pending status
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

    /// Update a loading item's status and count
    private func updateLoadingItem(name: String, status: LoadingItem.LoadingItemStatus, count: Int? = nil) {
        if let index = loadingItems.firstIndex(where: { $0.name == name }) {
            loadingItems[index].status = status
            if let count = count {
                loadingItems[index].count = count
            }
        }
    }

    init() {
        Task {
            await loadContentPacks()
        }
    }

    private func loadContentPacks() async {
        // Stage 1: Search for packs
        loadingStage = .searching
        loadingMessage = L10n.loadingSearchPacks.localized
        loadingProgress = 0.1

        let packURLs = await findPackURLs()

        guard !packURLs.isEmpty else {
            loadingMessage = L10n.loadingContentNotFound.localized
            #if DEBUG
            print("⚠️ ContentPacks not found - using fallback content")
            #endif
            finishLoading()
            return
        }

        // Stage 2: Load packs from JSON (multi-pack loading)
        // Note: Cache validation for multi-pack is more complex, loading directly for now
        loadingStage = .loadingFromJSON
        loadingMessage = L10n.loadingContent.localized
        loadingProgress = 0.3

        await loadPacksFromJSON(urls: packURLs)

        finishLoading()
    }

    // MARK: - Cache Validation

    private enum CacheValidationResult {
        case validCache(packId: String, contentHash: String)
        case invalidCache(contentHash: String?)
        case error
    }

    private func validateCache(for packURL: URL) async -> CacheValidationResult {
        return await Task.detached(priority: .userInitiated) { [cache] () -> CacheValidationResult in
            do {
                // Compute current content hash
                let contentHash = try CacheValidator.computeContentHash(for: packURL)

                // Load manifest to get pack ID
                let manifest = try PackManifest.load(from: packURL)

                // Check if cache is valid
                if cache.hasValidCache(for: manifest.packId, contentHash: contentHash) {
                    return .validCache(packId: manifest.packId, contentHash: contentHash)
                } else {
                    return .invalidCache(contentHash: contentHash)
                }
            } catch {
                #if DEBUG
                print("⚠️ Cache validation failed: \(error)")
                #endif
                return .error
            }
        }.value
    }

    // MARK: - Loading Methods

    private func loadFromCache(packId: String, expectedHash: String) async {
        isFromCache = true
        initializeLoadingItems()

        let result = await Task.detached(priority: .userInitiated) { [cache] () -> Result<CachedPackData, Error> in
            do {
                guard let cached = try cache.loadCachedPack(packId: packId) else {
                    return .failure(NSError(domain: "ContentCache", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pack not found in cache"]))
                }
                return .success(cached)
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let cached):
            loadingProgress = 0.8
            let pack = ContentRegistry.shared.loadPackFromCache(cached)
            loadingProgress = 0.9
            loadingMessage = L10n.loadingContentLoaded.localized

            // Update loading items with counts from cached pack
            updateLoadingItem(name: L10n.loadingItemRegions.localized, status: .loaded, count: pack.regions.count)
            updateLoadingItem(name: L10n.loadingItemEvents.localized, status: .loaded, count: pack.events.count)
            updateLoadingItem(name: L10n.loadingItemQuests.localized, status: .loaded, count: pack.quests.count)
            updateLoadingItem(name: L10n.loadingItemAnchors.localized, status: .loaded, count: pack.anchors.count)
            updateLoadingItem(name: L10n.loadingItemHeroes.localized, status: .loaded, count: pack.heroes.count)
            updateLoadingItem(name: L10n.loadingItemCards.localized, status: .loaded, count: pack.cards.count)
            updateLoadingItem(name: L10n.loadingItemEnemies.localized, status: .loaded, count: pack.enemies.count)
            updateLoadingItem(name: L10n.loadingItemLocalization.localized, status: .loaded, count: pack.manifest.supportedLocales.count)

            updateLoadingSummary(pack: pack)

        case .failure:
            // Cache corrupted or invalid, fall back to JSON
            // Cache corrupted, need to reload from JSON
            // This shouldn't happen normally but handle gracefully
            loadingStage = .loadingFromJSON
            loadingMessage = L10n.loadingContent.localized
            isFromCache = false
        }
    }

    private func loadPacksFromJSON(urls: [URL]) async {
        isFromCache = false
        initializeLoadingItems()

        let registry = ContentRegistry.shared

        let result = await Task.detached(priority: .userInitiated) { () -> Result<[LoadedPack], Error> in
            do {
                let packs = try registry.loadPacks(from: urls)
                return .success(packs)
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let packs):
            loadingProgress = 0.7

            // Aggregate counts from all loaded packs
            let inventory = registry.totalInventory

            // Update loading items with aggregated counts
            updateLoadingItem(name: L10n.loadingItemRegions.localized, status: .loaded, count: inventory.regionCount)
            updateLoadingItem(name: L10n.loadingItemEvents.localized, status: .loaded, count: inventory.eventCount)
            updateLoadingItem(name: L10n.loadingItemQuests.localized, status: .loaded, count: inventory.questCount)
            updateLoadingItem(name: L10n.loadingItemAnchors.localized, status: .loaded, count: inventory.anchorCount)
            updateLoadingItem(name: L10n.loadingItemHeroes.localized, status: .loaded, count: inventory.heroCount)
            updateLoadingItem(name: L10n.loadingItemCards.localized, status: .loaded, count: inventory.cardCount)
            updateLoadingItem(name: L10n.loadingItemEnemies.localized, status: .loaded, count: inventory.enemyCount)
            updateLoadingItem(name: L10n.loadingItemLocalization.localized, status: .loaded, count: inventory.supportedLocales.count)

            loadingProgress = 0.9
            loadingMessage = L10n.loadingContentLoaded.localized

            updateLoadingSummaryFromRegistry(packsLoaded: packs.count)

            #if DEBUG
            print("ContentLoader: Loaded \(packs.count) packs:")
            for pack in packs {
                print("  - \(pack.manifest.packId) (\(pack.manifest.packType.rawValue))")
            }
            #endif

        case .failure(let error):
            loadingMessage = L10n.loadingError.localized
            // Mark all items as failed
            for i in loadingItems.indices {
                loadingItems[i].status = .failed
            }
            #if DEBUG
            print("ContentLoader: Failed to load packs: \(error)")
            #endif
        }
    }

    private func loadFromJSON(at url: URL, contentHash: String?) async {
        isFromCache = false
        initializeLoadingItems()

        let registry = ContentRegistry.shared

        let result = await Task.detached(priority: .userInitiated) { () -> Result<LoadedPack, Error> in
            do {
                let pack = try registry.loadPack(from: url)
                return .success(pack)
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let pack):
            loadingProgress = 0.7

            // Update loading items with counts from loaded pack
            updateLoadingItem(name: L10n.loadingItemRegions.localized, status: .loaded, count: pack.regions.count)
            updateLoadingItem(name: L10n.loadingItemEvents.localized, status: .loaded, count: pack.events.count)
            updateLoadingItem(name: L10n.loadingItemQuests.localized, status: .loaded, count: pack.quests.count)
            updateLoadingItem(name: L10n.loadingItemAnchors.localized, status: .loaded, count: pack.anchors.count)
            updateLoadingItem(name: L10n.loadingItemHeroes.localized, status: .loaded, count: pack.heroes.count)
            updateLoadingItem(name: L10n.loadingItemCards.localized, status: .loaded, count: pack.cards.count)
            updateLoadingItem(name: L10n.loadingItemEnemies.localized, status: .loaded, count: pack.enemies.count)
            updateLoadingItem(name: L10n.loadingItemLocalization.localized, status: .loaded, count: pack.manifest.supportedLocales.count)

            // Stage 4: Save to cache
            if let hash = contentHash {
                loadingStage = .savingCache
                loadingMessage = L10n.loadingSavingCache.localized
                loadingProgress = 0.8

                saveToCache(pack: pack, contentHash: hash)
            }

            loadingProgress = 0.9
            loadingMessage = L10n.loadingContentLoaded.localized

            updateLoadingSummary(pack: pack)

        case .failure(let error):
            loadingMessage = L10n.loadingError.localized
            // Mark all items as failed
            for i in loadingItems.indices {
                loadingItems[i].status = .failed
            }
            #if DEBUG
            print("ContentLoader: Failed to load pack: \(error)")
            #endif
        }
    }

    private func saveToCache(pack: LoadedPack, contentHash: String) {
        Task.detached(priority: .background) { [cache] in
            try? cache.savePack(pack, contentHash: contentHash)
        }
    }

    // MARK: - Helpers

    private func findPackURLs() async -> [URL] {
        var urls: [URL] = []

        // Load character pack (CoreHeroes)
        if let heroesURL = CoreHeroesContent.packURL {
            urls.append(heroesURL)
            #if DEBUG
            print("🔍 CoreHeroesContent.packURL: \(heroesURL)")
            #endif
        }

        // Load story pack (TwilightMarchesActI)
        if let storyURL = TwilightMarchesActIContent.packURL {
            urls.append(storyURL)
            #if DEBUG
            print("🔍 TwilightMarchesActIContent.packURL: \(storyURL)")
            #endif
        }

        #if DEBUG
        print("🔍 Bundle.main.bundlePath: \(Bundle.main.bundlePath)")
        print("🔍 Found \(urls.count) content packs")
        #endif

        return urls
    }

    private func finishLoading() {
        loadingStage = .ready
        loadingProgress = 1.0
        loadingMessage = L10n.loadingReady.localized

        // Small delay to show completion
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // Longer delay to show summary
            isLoaded = true
        }
    }

    /// Update loading summary from pack
    private func updateLoadingSummary(pack: LoadedPack) {
        let totalItems = pack.regions.count + pack.events.count + pack.quests.count +
                         pack.heroes.count + pack.cards.count + pack.enemies.count
        loadingSummary = String(format: L10n.loadingSummary.localized, totalItems)
    }

    /// Update loading summary from registry (multi-pack)
    private func updateLoadingSummaryFromRegistry(packsLoaded: Int) {
        let inventory = ContentRegistry.shared.totalInventory
        let totalItems = inventory.regionCount + inventory.eventCount + inventory.questCount +
                         inventory.heroCount + inventory.cardCount + inventory.enemyCount
        loadingSummary = String(format: L10n.loadingSummary.localized, totalItems)
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

            // Show cache indicator
            if loader.isFromCache {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                    Text(L10n.loadingFromCacheIndicator.localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Show loading items when loading content
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
