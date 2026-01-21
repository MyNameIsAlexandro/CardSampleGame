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

/// Loads content packs on background thread to prevent main thread blocking
@MainActor
class ContentLoader: ObservableObject {
    @Published var isLoaded = false
    @Published var loadingProgress: Double = 0
    @Published var loadingMessage = L10n.loadingDefault.localized

    init() {
        Task {
            await loadContentPacks()
        }
    }

    private func loadContentPacks() async {
        loadingMessage = L10n.loadingSearchPacks.localized
        loadingProgress = 0.1

        // Run file operations on background thread
        let packURL: URL? = await Task.detached(priority: .userInitiated) { () -> URL? in
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
            #endif

            return nil
        }.value

        loadingProgress = 0.3

        if let url = packURL {
            loadingMessage = L10n.loadingContent.localized
            await loadPack(at: url)
        } else {
            loadingMessage = L10n.loadingContentNotFound.localized
            print("⚠️ ContentPacks not found - using fallback content")
        }

        loadingProgress = 1.0
        loadingMessage = L10n.loadingReady.localized

        // Small delay to show completion
        try? await Task.sleep(nanoseconds: 200_000_000)
        isLoaded = true
    }

    private func loadPack(at url: URL) async {
        let registry = ContentRegistry.shared

        // Run heavy loading on background thread
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
            loadingProgress = 0.9
            loadingMessage = L10n.loadingContentLoaded.localized
            print("✅ Loaded pack: \(pack.manifest.packId) v\(pack.manifest.version)")
            print("   - \(pack.regions.count) regions")
            print("   - \(pack.events.count) events")
            print("   - \(pack.quests.count) quests")
            print("   - \(pack.anchors.count) anchors")
            print("   - \(pack.heroes.count) heroes")
            print("   - \(pack.cards.count) cards")
        case .failure(let error):
            loadingMessage = L10n.loadingError.localized
            print("❌ Failed to load pack from \(url.path): \(error)")
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
