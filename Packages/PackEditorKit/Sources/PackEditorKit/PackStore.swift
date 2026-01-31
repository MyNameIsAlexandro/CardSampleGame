import Foundation
import TwilightEngine
import PackAuthoring

/// Pure-logic pack data store. No SwiftUI dependency.
/// The app wraps this in an @Observable / ObservableObject for UI binding.
public class PackStore {

    // MARK: - Pack Info

    public private(set) var loadedPack: LoadedPack?
    public private(set) var packURL: URL?
    public var isDirty: Bool = false

    // MARK: - Content Dictionaries

    public var enemies: [String: EnemyDefinition] = [:]
    public var cards: [String: StandardCardDefinition] = [:]
    public var events: [String: EventDefinition] = [:]
    public var regions: [String: RegionDefinition] = [:]
    public var heroes: [String: StandardHeroDefinition] = [:]
    public var fateCards: [String: FateCard] = [:]
    public var quests: [String: QuestDefinition] = [:]
    public var behaviors: [String: BehaviorDefinition] = [:]
    public var balanceConfig: BalanceConfiguration?

    // MARK: - Validation

    public private(set) var validationSummary: PackValidator.ValidationSummary?

    // MARK: - Init

    public init() {}

    // MARK: - Computed

    public var packTitle: String {
        if let pack = loadedPack {
            return "\(pack.manifest.packId) v\(pack.manifest.version)"
        }
        return "Pack Editor"
    }

    public func entityCount(for category: ContentCategory) -> Int {
        switch category {
        case .enemies: return enemies.count
        case .cards: return cards.count
        case .events: return events.count
        case .regions: return regions.count
        case .heroes: return heroes.count
        case .fateCards: return fateCards.count
        case .quests: return quests.count
        case .balance: return balanceConfig != nil ? 1 : 0
        }
    }

    public func entityIds(for category: ContentCategory) -> [String] {
        switch category {
        case .enemies: return enemies.keys.sorted()
        case .cards: return cards.keys.sorted()
        case .events: return events.keys.sorted()
        case .regions: return regions.keys.sorted()
        case .heroes: return heroes.keys.sorted()
        case .fateCards: return fateCards.keys.sorted()
        case .quests: return quests.keys.sorted()
        case .balance: return balanceConfig != nil ? ["balance"] : []
        }
    }

    public func entityName(for id: String, in category: ContentCategory) -> String {
        switch category {
        case .enemies: return enemies[id]?.name.displayString ?? id
        case .cards: return cards[id]?.name.displayString ?? id
        case .events: return events[id]?.title.displayString ?? id
        case .regions: return regions[id]?.title.displayString ?? id
        case .heroes: return heroes[id]?.name.displayString ?? id
        case .fateCards: return fateCards[id]?.name ?? id
        case .quests: return quests[id]?.title.displayString ?? id
        case .balance: return "Balance Configuration"
        }
    }

    // MARK: - Load Pack

    public func loadPack(from url: URL) throws {
        let manifest = try PackManifest.load(from: url)
        let pack = try PackLoader.load(manifest: manifest, from: url)

        self.loadedPack = pack
        self.packURL = url
        self.enemies = pack.enemies
        self.cards = pack.cards
        self.events = pack.events
        self.regions = pack.regions
        self.heroes = pack.heroes
        self.fateCards = pack.fateCards
        self.quests = pack.quests
        self.behaviors = pack.behaviors
        self.balanceConfig = pack.balanceConfig
        self.isDirty = false
    }

    // MARK: - Save Pack

    public func savePack() throws {
        guard let url = packURL, let manifest = loadedPack?.manifest else {
            throw PackStoreError.noPackLoaded
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let path = manifest.regionsPath {
            let data = try encoder.encode(Array(regions.values))
            try data.write(to: url.appendingPathComponent(path))
        }
        if let path = manifest.eventsPath {
            let data = try encoder.encode(Array(events.values))
            try data.write(to: url.appendingPathComponent(path))
        }
        if let path = manifest.questsPath {
            let data = try encoder.encode(Array(quests.values))
            try data.write(to: url.appendingPathComponent(path))
        }
        if let path = manifest.heroesPath {
            let data = try encoder.encode(Array(heroes.values))
            try data.write(to: url.appendingPathComponent(path))
        }
        if let path = manifest.cardsPath {
            let data = try encoder.encode(Array(cards.values))
            try data.write(to: url.appendingPathComponent(path))
        }
        if let path = manifest.enemiesPath {
            let data = try encoder.encode(Array(enemies.values))
            try data.write(to: url.appendingPathComponent(path))
        }
        if let path = manifest.fateDeckPath {
            let data = try encoder.encode(Array(fateCards.values))
            try data.write(to: url.appendingPathComponent(path))
        }
        if let path = manifest.balancePath, let config = balanceConfig {
            let data = try encoder.encode(config)
            try data.write(to: url.appendingPathComponent(path))
        }

        isDirty = false
    }

    // MARK: - Validate

    @discardableResult
    public func validate() -> PackValidator.ValidationSummary? {
        guard let url = packURL else {
            validationSummary = nil
            return nil
        }
        let validator = PackValidator(packURL: url)
        let summary = validator.validate()
        validationSummary = summary
        return summary
    }
}

// MARK: - Errors

public enum PackStoreError: Error, LocalizedError {
    case noPackLoaded

    public var errorDescription: String? {
        switch self {
        case .noPackLoaded: return "No pack is loaded"
        }
    }
}

// MARK: - LocalizableText Display Helper

extension LocalizableText {
    /// Returns the English text for inline strings, or the key string for key-based text.
    public var displayString: String {
        switch self {
        case .inline(let localized):
            return localized.en
        case .key(let key):
            return key.rawValue
        }
    }
}
