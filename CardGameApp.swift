import SwiftUI

@main
struct CardGameApp: App {

    init() {
        // Load content packs at app startup
        loadContentPacks()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// Load all content packs from the bundle
    private func loadContentPacks() {
        let registry = ContentRegistry.shared

        // Find ContentPacks in the bundle
        // First try bundle resource
        if let packURL = Bundle.main.url(forResource: "TwilightMarches", withExtension: nil, subdirectory: "ContentPacks") {
            loadPack(at: packURL, registry: registry)
            return
        }

        // Try finding ContentPacks directory in bundle
        if let resourceURL = Bundle.main.resourceURL {
            let contentPacksURL = resourceURL.appendingPathComponent("ContentPacks/TwilightMarches")
            if FileManager.default.fileExists(atPath: contentPacksURL.path) {
                loadPack(at: contentPacksURL, registry: registry)
                return
            }
        }

        // Fallback: Try source directory path (for development/debugging)
        #if DEBUG
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("ContentPacks/TwilightMarches")
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            loadPack(at: sourceURL, registry: registry)
            return
        }
        #endif

        print("⚠️ ContentPacks not found - using fallback content")
    }

    private func loadPack(at url: URL, registry: ContentRegistry) {
        do {
            let pack = try registry.loadPack(from: url)
            print("✅ Loaded pack: \(pack.manifest.packId) v\(pack.manifest.version)")
            print("   - \(pack.regions.count) regions")
            print("   - \(pack.events.count) events")
            print("   - \(pack.quests.count) quests")
            print("   - \(pack.anchors.count) anchors")
            print("   - \(pack.heroes.count) heroes")
            print("   - \(pack.cards.count) cards")
        } catch {
            print("❌ Failed to load pack from \(url.path): \(error)")
        }
    }
}
