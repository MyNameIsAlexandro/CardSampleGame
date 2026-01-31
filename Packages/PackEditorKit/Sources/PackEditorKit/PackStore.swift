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
        encoder.keyEncodingStrategy = .convertToSnakeCase

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

    // MARK: - Add Entity

    @discardableResult
    public func addEntity(for category: ContentCategory) -> String? {
        let uuid = UUID().uuidString.prefix(8).lowercased()

        switch category {
        case .enemies:
            let id = "enemy_new_\(uuid)"
            enemies[id] = EnemyDefinition(
                id: id,
                name: .inline(LocalizedString(en: "New Enemy", ru: "Новый враг")),
                description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                health: 10, power: 2, defense: 0
            )
            isDirty = true
            return id

        case .cards:
            let id = "card_new_\(uuid)"
            cards[id] = StandardCardDefinition(
                id: id,
                name: .inline(LocalizedString(en: "New Card", ru: "Новая карта")),
                cardType: .item,
                description: .inline(LocalizedString(en: "Description", ru: "Описание"))
            )
            isDirty = true
            return id

        case .events:
            let id = "event_new_\(uuid)"
            events[id] = EventDefinition(
                id: id,
                title: .inline(LocalizedString(en: "New Event", ru: "Новое событие")),
                body: .inline(LocalizedString(en: "Event body", ru: "Текст события"))
            )
            isDirty = true
            return id

        case .regions:
            let id = "region_new_\(uuid)"
            regions[id] = RegionDefinition(
                id: id,
                title: .inline(LocalizedString(en: "New Region", ru: "Новый регион")),
                description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                regionType: "default",
                neighborIds: []
            )
            isDirty = true
            return id

        case .heroes:
            let id = "hero_new_\(uuid)"
            heroes[id] = StandardHeroDefinition(
                id: id,
                name: .inline(LocalizedString(en: "New Hero", ru: "Новый герой")),
                description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                icon: "🛡️",
                baseStats: HeroStats(
                    health: 20, maxHealth: 20,
                    strength: 3, dexterity: 3, constitution: 3,
                    intelligence: 3, wisdom: 3, charisma: 3,
                    faith: 5, maxFaith: 10, startingBalance: 0
                ),
                specialAbility: HeroAbility(
                    id: "\(id)_ability",
                    name: .inline(LocalizedString(en: "New Ability", ru: "Новая способность")),
                    description: .inline(LocalizedString(en: "Ability description", ru: "Описание способности")),
                    icon: "⚡",
                    type: .passive,
                    trigger: .always,
                    condition: nil,
                    effects: [],
                    cooldown: 0,
                    cost: nil
                )
            )
            isDirty = true
            return id

        case .fateCards:
            let id = "fate_new_\(uuid)"
            fateCards[id] = FateCard(
                id: id, modifier: 0, name: "New Fate Card"
            )
            isDirty = true
            return id

        case .quests:
            let id = "quest_new_\(uuid)"
            quests[id] = QuestDefinition(
                id: id,
                title: .inline(LocalizedString(en: "New Quest", ru: "Новый квест")),
                description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                objectives: []
            )
            isDirty = true
            return id

        case .balance:
            return nil // singleton
        }
    }

    // MARK: - Duplicate Entity

    @discardableResult
    public func duplicateEntity(id: String, for category: ContentCategory) -> String? {
        let uuid = UUID().uuidString.prefix(8).lowercased()

        switch category {
        case .enemies:
            guard var copy = enemies[id] else { return nil }
            let newId = "\(id)_copy_\(uuid)"
            copy.id = newId
            enemies[newId] = copy
            isDirty = true
            return newId

        case .cards:
            guard var copy = cards[id] else { return nil }
            let newId = "\(id)_copy_\(uuid)"
            copy.id = newId
            cards[newId] = copy
            isDirty = true
            return newId

        case .events:
            guard var copy = events[id] else { return nil }
            let newId = "\(id)_copy_\(uuid)"
            copy.id = newId
            events[newId] = copy
            isDirty = true
            return newId

        case .regions:
            guard var copy = regions[id] else { return nil }
            let newId = "\(id)_copy_\(uuid)"
            copy.id = newId
            regions[newId] = copy
            isDirty = true
            return newId

        case .heroes:
            guard var copy = heroes[id] else { return nil }
            let newId = "\(id)_copy_\(uuid)"
            copy.id = newId
            heroes[newId] = copy
            isDirty = true
            return newId

        case .fateCards:
            guard var copy = fateCards[id] else { return nil }
            let newId = "\(id)_copy_\(uuid)"
            copy.id = newId
            fateCards[newId] = copy
            isDirty = true
            return newId

        case .quests:
            guard var copy = quests[id] else { return nil }
            let newId = "\(id)_copy_\(uuid)"
            copy.id = newId
            quests[newId] = copy
            isDirty = true
            return newId

        case .balance:
            return nil
        }
    }

    // MARK: - Delete Entity

    public func deleteEntity(id: String, for category: ContentCategory) {
        switch category {
        case .enemies: enemies.removeValue(forKey: id)
        case .cards: cards.removeValue(forKey: id)
        case .events: events.removeValue(forKey: id)
        case .regions: regions.removeValue(forKey: id)
        case .heroes: heroes.removeValue(forKey: id)
        case .fateCards: fateCards.removeValue(forKey: id)
        case .quests: quests.removeValue(forKey: id)
        case .balance: return // can't delete singleton
        }
        isDirty = true
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
