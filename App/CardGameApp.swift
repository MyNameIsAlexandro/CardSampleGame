import SwiftUI

@main
struct CardGameApp: App {
    @StateObject private var contentLoader = ContentLoader()

    var body: some Scene {
        WindowGroup {
            if contentLoader.isLoaded {
                ContentView()
            } else {
                LoadingView(progress: contentLoader.loadingProgress, message: contentLoader.loadingMessage)
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

/// Loads content packs with caching support
/// - First launch: loads from JSON, saves to cache
/// - Subsequent launches: loads from cache if valid
@MainActor
class ContentLoader: ObservableObject {
    @Published var isLoaded = false
    @Published var loadingProgress: Double = 0
    @Published var loadingMessage = L10n.loadingDefault.localized
    @Published var loadingStage: LoadingStage = .searching

    private let cache = FileSystemCache.shared

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

        let packURL = await findPackURL()

        guard let url = packURL else {
            loadingMessage = L10n.loadingContentNotFound.localized
            print("⚠️ ContentPacks not found - using fallback content")
            finishLoading()
            return
        }

        // Stage 2: Validate cache
        loadingStage = .validatingCache
        loadingMessage = L10n.loadingValidatingCache.localized
        loadingProgress = 0.2

        let cacheResult = await validateCache(for: url)

        switch cacheResult {
        case .validCache(let packId, let contentHash):
            // Stage 3a: Load from cache (fast path)
            loadingStage = .loadingFromCache
            loadingMessage = L10n.loadingFromCache.localized
            loadingProgress = 0.5

            await loadFromCache(packId: packId, expectedHash: contentHash)

        case .invalidCache(let contentHash):
            // Stage 3b: Load from JSON (slow path)
            loadingStage = .loadingFromJSON
            loadingMessage = L10n.loadingContent.localized
            loadingProgress = 0.3

            await loadFromJSON(at: url, contentHash: contentHash)

        case .error:
            // Fallback to JSON loading without caching
            loadingStage = .loadingFromJSON
            loadingMessage = L10n.loadingContent.localized
            loadingProgress = 0.3

            await loadFromJSON(at: url, contentHash: nil)
        }

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
                print("⚠️ Cache validation failed: \(error)")
                return .error
            }
        }.value
    }

    // MARK: - Loading Methods

    private func loadFromCache(packId: String, expectedHash: String) async {
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
            _ = ContentRegistry.shared.loadPackFromCache(cached)
            loadingProgress = 0.9
            loadingMessage = L10n.loadingContentLoaded.localized

        case .failure:
            // Cache corrupted or invalid, fall back to JSON
            // Cache corrupted, need to reload from JSON
            // This shouldn't happen normally but handle gracefully
            loadingStage = .loadingFromJSON
            loadingMessage = L10n.loadingContent.localized
        }
    }

    private func loadFromJSON(at url: URL, contentHash: String?) async {
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

            // Stage 4: Save to cache
            if let hash = contentHash {
                loadingStage = .savingCache
                loadingMessage = L10n.loadingSavingCache.localized
                loadingProgress = 0.8

                saveToCache(pack: pack, contentHash: hash)
            }

            loadingProgress = 0.9
            loadingMessage = L10n.loadingContentLoaded.localized

        case .failure:
            loadingMessage = L10n.loadingError.localized
        }
    }

    private func saveToCache(pack: LoadedPack, contentHash: String) {
        Task.detached(priority: .background) { [cache] in
            try? cache.savePack(pack, contentHash: contentHash)
        }
    }

    // MARK: - Helpers

    private func findPackURL() async -> URL? {
        return await Task.detached(priority: .userInitiated) { () -> URL? in
            // Find ContentPacks in the bundle
            if let url = Bundle.main.url(forResource: "TwilightMarches", withExtension: nil, subdirectory: "ContentPacks") {
                return url
            }

            // Try finding ContentPacks directory in bundle
            if let resourceURL = Bundle.main.resourceURL {
                let contentPacksURL = resourceURL.appendingPathComponent("ContentPacks/TwilightMarches")
                if FileManager.default.fileExists(atPath: contentPacksURL.path) {
                    return contentPacksURL
                }
            }

            // Fallback: Try source directory path (for development/debugging)
            #if DEBUG
            let sourceURL = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("ContentPacks/TwilightMarches")
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                return sourceURL
            }

            // Additional fallback: Project root ContentPacks
            let projectRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("ContentPacks/TwilightMarches")
            if FileManager.default.fileExists(atPath: projectRoot.path) {
                return projectRoot
            }
            #endif

            return nil
        }.value
    }

    private func finishLoading() {
        loadingStage = .ready
        loadingProgress = 1.0
        loadingMessage = L10n.loadingReady.localized

        // Small delay to show completion
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            isLoaded = true
        }
    }
}

// MARK: - Loading View

struct LoadingView: View {
    let progress: Double
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Text(L10n.appTitle.localized)
                .font(.largeTitle)
                .fontWeight(.bold)

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
