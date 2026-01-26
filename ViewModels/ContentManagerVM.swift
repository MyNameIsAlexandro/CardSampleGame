import Foundation
import SwiftUI
import TwilightEngine

/// ViewModel for Content Manager UI
@MainActor
public final class ContentManagerVM: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var packs: [ManagedPack] = []
    @Published public private(set) var isScanning = false
    @Published public var lastError: String?
    @Published public var selectedPackId: String?

    /// Bundled pack URLs (injected from app)
    private var bundledPackURLs: [URL] = []

    // MARK: - Computed Properties

    public var bundledPacks: [ManagedPack] {
        packs.filter { if case .bundled = $0.source { return true } else { return false } }
    }

    public var externalPacks: [ManagedPack] {
        packs.filter { if case .external = $0.source { return true } else { return false } }
    }

    public var loadedPacks: [ManagedPack] {
        packs.filter { $0.state == .loaded }
    }

    public var loadedCount: Int {
        loadedPacks.count
    }

    public var errorCount: Int {
        packs.filter { $0.hasErrors }.count
    }

    public var warningCount: Int {
        packs.filter { $0.hasWarnings }.count
    }

    public var selectedPack: ManagedPack? {
        guard let id = selectedPackId else { return nil }
        return packs.first { $0.id == id }
    }

    public var externalPacksPath: String {
        ContentManager.shared.externalPacksDirectory().path
    }

    // MARK: - Initialization

    public init() {}

    /// Set bundled pack URLs (call from app)
    public func setBundledPackURLs(_ urls: [URL]) {
        self.bundledPackURLs = urls
    }

    // MARK: - Actions

    /// Refresh pack list
    public func refresh() async {
        isScanning = true
        lastError = nil

        // Discover packs
        let discovered = await Task.detached { [bundledPackURLs] in
            ContentManager.shared.discoverPacks(bundledURLs: bundledPackURLs)
        }.value

        packs = discovered.sorted { $0.id < $1.id }
        isScanning = false
    }

    /// Select a pack for detail view
    public func selectPack(_ packId: String) {
        selectedPackId = packId
    }

    /// Clear selection
    public func clearSelection() {
        selectedPackId = nil
    }

    /// Validate a specific pack
    public func validatePack(_ packId: String) async {
        guard let index = packs.firstIndex(where: { $0.id == packId }) else { return }

        // Update UI to show validating
        packs[index].state = .validating

        // Perform validation
        let summary = await ContentManager.shared.validatePack(packId)

        // Update UI with result
        if let newIndex = packs.firstIndex(where: { $0.id == packId }) {
            packs[newIndex].state = .validated(summary)
            packs[newIndex].lastValidation = summary
        }
    }

    /// Load a pack (after validation)
    public func loadPack(_ packId: String) async {
        guard let index = packs.firstIndex(where: { $0.id == packId }) else { return }

        packs[index].state = .loading
        lastError = nil

        do {
            _ = try await ContentManager.shared.loadPack(packId)
            if let newIndex = packs.firstIndex(where: { $0.id == packId }) {
                packs[newIndex].state = .loaded
                packs[newIndex].loadedAt = Date()
            }
        } catch {
            if let newIndex = packs.firstIndex(where: { $0.id == packId }) {
                packs[newIndex].state = .failed(error.localizedDescription)
            }
            lastError = error.localizedDescription
        }
    }

    /// Reload a pack (hot-reload)
    public func reloadPack(_ packId: String) async {
        guard let index = packs.firstIndex(where: { $0.id == packId }) else { return }

        packs[index].state = .validating
        lastError = nil

        let result = await ContentManager.shared.safeReloadPack(packId)

        switch result {
        case .success:
            if let newIndex = packs.firstIndex(where: { $0.id == packId }) {
                packs[newIndex].state = .loaded
                packs[newIndex].loadedAt = Date()
            }

        case .failure(let error):
            if let newIndex = packs.firstIndex(where: { $0.id == packId }) {
                switch error {
                case .validationFailed(let summary):
                    packs[newIndex].state = .validated(summary)
                    packs[newIndex].lastValidation = summary
                default:
                    packs[newIndex].state = .failed(error.localizedDescription)
                }
            }
            lastError = error.localizedDescription
        }
    }

    /// Reload all external packs
    public func reloadAllExternal() async {
        for pack in externalPacks where pack.canReload {
            await reloadPack(pack.id)
        }
    }

    /// Validate all discovered (not loaded) packs
    public func validateAll() async {
        for pack in packs where pack.state == .discovered {
            await validatePack(pack.id)
        }
    }

    // MARK: - File Operations

    #if os(iOS)
    /// Open external packs folder in Files app
    public func openExternalPacksFolder() {
        let url = ContentManager.shared.externalPacksDirectory()
        // Use shareddocuments URL scheme to open in Files app
        if let filesURL = URL(string: "shareddocuments://\(url.path)") {
            UIApplication.shared.open(filesURL)
        }
    }
    #endif

    /// Copy path to clipboard
    public func copyPathToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = externalPacksPath
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(externalPacksPath, forType: .string)
        #endif
    }
}

// MARK: - Pack Display Helpers

extension ManagedPack {
    /// Formatted file size
    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// Formatted modification date
    public var formattedModifiedAt: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modifiedAt)
    }

    /// Formatted load date
    public var formattedLoadedAt: String? {
        guard let loadedAt = loadedAt else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: loadedAt)
    }

    /// Content summary string
    public var contentSummary: String {
        guard let manifest = manifest else { return "Unknown content" }

        var parts: [String] = []

        // Get counts from ContentRegistry if loaded
        if case .loaded = state {
            let registry = ContentRegistry.shared
            if let pack = registry.loadedPacks[id] {
                if !pack.heroes.isEmpty { parts.append("\(pack.heroes.count) heroes") }
                if !pack.cards.isEmpty { parts.append("\(pack.cards.count) cards") }
                if !pack.regions.isEmpty { parts.append("\(pack.regions.count) regions") }
                if !pack.events.isEmpty { parts.append("\(pack.events.count) events") }
                if !pack.quests.isEmpty { parts.append("\(pack.quests.count) quests") }
                if !pack.enemies.isEmpty { parts.append("\(pack.enemies.count) enemies") }
            }
        }

        if parts.isEmpty {
            return manifest.packType.rawValue.capitalized
        }

        return parts.joined(separator: ", ")
    }

    /// Display name
    public var displayName: String {
        manifest?.displayName.localized ?? id
    }

    /// Version string
    public var versionString: String {
        manifest?.version.description ?? "?"
    }

    /// Pack type display
    public var packTypeDisplay: String {
        manifest?.packType.rawValue.capitalized ?? "Unknown"
    }
}
