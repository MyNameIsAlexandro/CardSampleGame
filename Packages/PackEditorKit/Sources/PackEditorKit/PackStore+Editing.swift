/// Файл: Packages/PackEditorKit/Sources/PackEditorKit/PackStore+Editing.swift
/// Назначение: Содержит реализацию файла PackStore+Editing.swift.
/// Зона ответственности: Реализует пакетный API редактора контента.
/// Контекст: Используется в переиспользуемом пакетном модуле проекта.

import Foundation
import TwilightEngine
import PackAuthoring

extension PackStore {

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
            default:
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
            default:
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
                heroClass: .warrior,
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
            fateCards[id] = FateCard(id: id, modifier: 0, name: "New Fate Card")
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
            return nil
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
        case .balance: return
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
}
