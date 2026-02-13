/// Файл: ViewModels/ContentManagerVM.swift
/// Назначение: Содержит реализацию файла ContentManagerVM.swift.
/// Зона ответственности: Отвечает за состояние и оркестрацию сценариев экрана.
/// Контекст: Используется в приложении CardSampleGame и связанных потоках выполнения.

import Foundation
import Combine
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

    private let contentManager: ContentManager
    private let registry: ContentRegistry

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
        contentManager.externalPacksDirectory().path
    }

    // MARK: - Initialization

    public init(contentManager: ContentManager, registry: ContentRegistry) {
        self.contentManager = contentManager
        self.registry = registry
    }

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
        let discovered = contentManager.discoverPacks(bundledURLs: bundledPackURLs)

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
        let summary = await contentManager.validatePack(packId)

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
            _ = try await contentManager.loadPack(packId)
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

        let result = await contentManager.safeReloadPack(packId)

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

    public func contentSummary(for pack: ManagedPack) -> String {
        guard let manifest = pack.manifest else { return "Unknown content" }

        var parts: [String] = []

        if pack.state == .loaded, let loadedPack = registry.loadedPacks[pack.id] {
            if !loadedPack.heroes.isEmpty { parts.append("\(loadedPack.heroes.count) heroes") }
            if !loadedPack.cards.isEmpty { parts.append("\(loadedPack.cards.count) cards") }
            if !loadedPack.regions.isEmpty { parts.append("\(loadedPack.regions.count) regions") }
            if !loadedPack.events.isEmpty { parts.append("\(loadedPack.events.count) events") }
            if !loadedPack.quests.isEmpty { parts.append("\(loadedPack.quests.count) quests") }
            if !loadedPack.enemies.isEmpty { parts.append("\(loadedPack.enemies.count) enemies") }
        }

        if parts.isEmpty {
            return manifest.packType.rawValue.capitalized
        }

        return parts.joined(separator: ", ")
    }

    public func loadedPack(for packId: String) -> LoadedPack? {
        registry.loadedPacks[packId]
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
