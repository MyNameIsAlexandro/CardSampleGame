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

    /// Editable manifest accessor
    public var manifest: PackManifest? {
        get { loadedPack?.manifest }
        set {
            if let newValue { loadedPack?.manifest = newValue }
        }
    }

    // MARK: - Content Dictionaries

    public var enemies: [String: EnemyDefinition] = [:]
    public var cards: [String: StandardCardDefinition] = [:]
    public var events: [String: EventDefinition] = [:]
    public var regions: [String: RegionDefinition] = [:]
    public var heroes: [String: StandardHeroDefinition] = [:]
    public var fateCards: [String: FateCard] = [:]
    public var quests: [String: QuestDefinition] = [:]
    public var behaviors: [String: BehaviorDefinition] = [:]
    public var anchors: [String: AnchorDefinition] = [:]
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
        case .behaviors: return behaviors.count
        case .anchors: return anchors.count
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
        case .behaviors: return behaviors.keys.sorted()
        case .anchors: return anchors.keys.sorted()
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
        case .behaviors: return id
        case .anchors: return anchors[id]?.title.displayString ?? id
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
        self.anchors = pack.anchors
        self.balanceConfig = pack.balanceConfig
        self.isDirty = false
        self.loadEntityOrder()
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
        if let path = manifest.behaviorsPath {
            let data = try encoder.encode(Array(behaviors.values))
            try data.write(to: url.appendingPathComponent(path))
        }
        if let path = manifest.anchorsPath {
            let data = try encoder.encode(Array(anchors.values))
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
    public func addEntity(for category: ContentCategory, template: String? = nil) -> String? {
        let uuid = UUID().uuidString.prefix(8).lowercased()

        switch category {
        case .enemies:
            let id = "enemy_new_\(uuid)"
            let effectiveTemplate = template ?? "beast"
            switch effectiveTemplate {
            case "undead":
                enemies[id] = EnemyDefinition(
                    id: id,
                    name: .inline(LocalizedString(en: "New Undead", ru: "Новая нежить")),
                    description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                    health: 15, power: 3, defense: 1,
                    enemyType: .undead, rarity: .uncommon,
                    will: 5
                )
            case "boss":
                enemies[id] = EnemyDefinition(
                    id: id,
                    name: .inline(LocalizedString(en: "New Boss", ru: "Новый босс")),
                    description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                    health: 30, power: 5, defense: 3,
                    difficulty: 3,
                    enemyType: .boss, rarity: .epic
                )
            default: // "beast"
                enemies[id] = EnemyDefinition(
                    id: id,
                    name: .inline(LocalizedString(en: "New Beast", ru: "Новый зверь")),
                    description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                    health: 10, power: 2, defense: 0,
                    enemyType: .beast, rarity: .common
                )
            }
            isDirty = true
            return id

        case .cards:
            let id = "card_new_\(uuid)"
            let effectiveTemplate = template ?? "item"
            let cardType: CardType
            let nameEN: String
            let nameRU: String
            switch effectiveTemplate {
            case "attack":
                cardType = .weapon
                nameEN = "New Attack"
                nameRU = "Новая атака"
            case "defense":
                cardType = .armor
                nameEN = "New Defense"
                nameRU = "Новая защита"
            case "spell":
                cardType = .spell
                nameEN = "New Spell"
                nameRU = "Новое заклинание"
            default: // "item"
                cardType = .item
                nameEN = "New Item"
                nameRU = "Новый предмет"
            }
            cards[id] = StandardCardDefinition(
                id: id,
                name: .inline(LocalizedString(en: nameEN, ru: nameRU)),
                cardType: cardType,
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
            let effectiveTemplate = template ?? "default"
            switch effectiveTemplate {
            case "settlement":
                regions[id] = RegionDefinition(
                    id: id,
                    title: .inline(LocalizedString(en: "New Settlement", ru: "Новое поселение")),
                    description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                    regionType: "settlement",
                    neighborIds: [],
                    initialState: .stable
                )
            case "wilderness":
                regions[id] = RegionDefinition(
                    id: id,
                    title: .inline(LocalizedString(en: "New Wilderness", ru: "Новая глушь")),
                    description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                    regionType: "wilderness",
                    neighborIds: [],
                    initialState: .stable
                )
            case "dungeon":
                regions[id] = RegionDefinition(
                    id: id,
                    title: .inline(LocalizedString(en: "New Dungeon", ru: "Новое подземелье")),
                    description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                    regionType: "dungeon",
                    neighborIds: [],
                    initialState: .borderland
                )
            default:
                regions[id] = RegionDefinition(
                    id: id,
                    title: .inline(LocalizedString(en: "New Region", ru: "Новый регион")),
                    description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                    regionType: "default",
                    neighborIds: []
                )
            }
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

        case .behaviors:
            let id = "behavior_new_\(uuid)"
            behaviors[id] = BehaviorDefinition(
                id: id,
                rules: [],
                defaultIntent: "attack",
                defaultValue: "1"
            )
            isDirty = true
            return id

        case .anchors:
            let id = "anchor_new_\(uuid)"
            anchors[id] = AnchorDefinition(
                id: id,
                title: .inline(LocalizedString(en: "New Anchor", ru: "Новый якорь")),
                description: .inline(LocalizedString(en: "Description", ru: "Описание")),
                regionId: ""
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

        case .behaviors:
            guard var copy = behaviors[id] else { return nil }
            let newId = "\(id)_copy_\(uuid)"
            copy.id = newId
            behaviors[newId] = copy
            isDirty = true
            return newId

        case .anchors:
            guard var copy = anchors[id] else { return nil }
            let newId = "\(id)_copy_\(uuid)"
            copy.id = newId
            anchors[newId] = copy
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
        case .behaviors: behaviors.removeValue(forKey: id)
        case .anchors: anchors.removeValue(forKey: id)
        case .balance: return // can't delete singleton
        }
        isDirty = true
    }

    // MARK: - Save Manifest

    public func saveManifest() throws {
        guard let url = packURL, let manifest = loadedPack?.manifest else {
            throw PackStoreError.noPackLoaded
        }
        try manifest.save(to: url)
        isDirty = false
    }

    // MARK: - Import Entity

    /// Import an entity from JSON data into the given category.
    /// Returns the imported entity's ID, or nil if decoding fails.
    @discardableResult
    public func importEntity(json: Data, for category: ContentCategory) throws -> String? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        switch category {
        case .enemies:
            let entity = try decoder.decode(EnemyDefinition.self, from: json)
            enemies[entity.id] = entity
            isDirty = true
            return entity.id
        case .cards:
            let entity = try decoder.decode(StandardCardDefinition.self, from: json)
            cards[entity.id] = entity
            isDirty = true
            return entity.id
        case .events:
            let entity = try decoder.decode(EventDefinition.self, from: json)
            events[entity.id] = entity
            isDirty = true
            return entity.id
        case .regions:
            let entity = try decoder.decode(RegionDefinition.self, from: json)
            regions[entity.id] = entity
            isDirty = true
            return entity.id
        case .heroes:
            let entity = try decoder.decode(StandardHeroDefinition.self, from: json)
            heroes[entity.id] = entity
            isDirty = true
            return entity.id
        case .fateCards:
            let entity = try decoder.decode(FateCard.self, from: json)
            fateCards[entity.id] = entity
            isDirty = true
            return entity.id
        case .quests:
            let entity = try decoder.decode(QuestDefinition.self, from: json)
            quests[entity.id] = entity
            isDirty = true
            return entity.id
        case .behaviors:
            let entity = try decoder.decode(BehaviorDefinition.self, from: json)
            behaviors[entity.id] = entity
            isDirty = true
            return entity.id
        case .anchors:
            let entity = try decoder.decode(AnchorDefinition.self, from: json)
            anchors[entity.id] = entity
            isDirty = true
            return entity.id
        case .balance:
            return nil
        }
    }

    // MARK: - Export Entity

    /// Export a single entity as JSON data.
    public func exportEntityJSON(id: String, for category: ContentCategory) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.keyEncodingStrategy = .convertToSnakeCase

        switch category {
        case .enemies: return try? encoder.encode(enemies[id])
        case .cards: return try? encoder.encode(cards[id])
        case .events: return try? encoder.encode(events[id])
        case .regions: return try? encoder.encode(regions[id])
        case .heroes: return try? encoder.encode(heroes[id])
        case .fateCards: return try? encoder.encode(fateCards[id])
        case .quests: return try? encoder.encode(quests[id])
        case .behaviors: return try? encoder.encode(behaviors[id])
        case .anchors: return try? encoder.encode(anchors[id])
        case .balance: return try? encoder.encode(balanceConfig)
        }
    }

    // MARK: - Entity Order (Drag-Reorder)

    /// Custom entity ordering per category. If nil for a category, alphabetical sort is used.
    public var entityOrder: [ContentCategory: [String]] = [:]

    /// Returns ordered entity IDs — custom order if available, otherwise alphabetical.
    public func orderedEntityIds(for category: ContentCategory) -> [String] {
        if let order = entityOrder[category] {
            // Filter to only IDs that still exist, append any new ones
            let existingIds = Set(entityIds(for: category))
            let ordered = order.filter { existingIds.contains($0) }
            let remaining = entityIds(for: category).filter { !order.contains($0) }
            return ordered + remaining
        }
        return entityIds(for: category)
    }

    /// Save entity order to _editor_order.json in pack directory.
    public func saveEntityOrder() throws {
        guard let url = packURL else { throw PackStoreError.noPackLoaded }
        let orderURL = url.appendingPathComponent("_editor_order.json")
        let dict = Dictionary(uniqueKeysWithValues: entityOrder.map { ($0.key.rawValue, $0.value) })
        let data = try JSONEncoder().encode(dict)
        try data.write(to: orderURL)
    }

    /// Load entity order from _editor_order.json in pack directory.
    public func loadEntityOrder() {
        guard let url = packURL else { return }
        let orderURL = url.appendingPathComponent("_editor_order.json")
        guard let data = try? Data(contentsOf: orderURL),
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else { return }
        entityOrder = Dictionary(uniqueKeysWithValues: dict.compactMap { key, value in
            guard let cat = ContentCategory(rawValue: key) else { return nil }
            return (cat, value)
        })
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
