/// Файл: App/Loading/ContentLoader.swift
/// Назначение: Асинхронная загрузка бинарных контент-паков приложения.
/// Зона ответственности: Поиск паков, загрузка в registry, базовая валидация, выдача AppServices.
/// Контекст: Используется стартовым экраном при инициализации CardSampleGame.

import Foundation
import CoreHeroesContent
import TwilightEngine
import TwilightMarchesActIContent

@MainActor
final class ContentLoader: ObservableObject {
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

    private func findPackURLs() -> [URL] {
        var urls: [URL] = []

        if let heroesURL = CoreHeroesContent.packURL {
            urls.append(heroesURL)
            verboseLog("🔍 CoreHeroes pack: \(heroesURL)")
        }

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
            if let count {
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
